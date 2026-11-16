import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/features/portfolio/data/trading_history_mapper.dart';
import 'package:vanta/features/portfolio/data/income_archive_repository.dart';
import 'package:vanta/features/notifications/data/api_notification_symbols_repository.dart';

import 'income_archive_repository_test.dart' show IncomeSource;

import 'package:vanta/features/portfolio/data/trading_history_repository.dart';
import 'package:vanta/features/portfolio/domain/trading_history.dart';
import 'package:vanta/features/settings/data/app_update_repository.dart';

import '../../support/trading_history.dart';
import '../../support/vanta_api.dart';
import '../notifications/api_notification_transport_test.dart' as transport;

void main() {
  for (final operation in [
    'orders',
    'order fills',
    'related orders',
    'update check',
    'income report',
    'notification units',
  ]) {
    for (final headers in [false, true]) {
      for (final stop in ['cancel', 'timeout', 'dispose']) {
        test(
          '$operation $stop aborts ${headers ? 'body' : 'headers'} without affecting another read',
          () async {
            final client = transport.Transport();
            final api = await transport.session(
              client,
              timeout: stop == 'timeout'
                  ? const Duration(milliseconds: 500)
                  : const Duration(seconds: 2),
            );
            addTearDown(api.close);
            final updates = AppUpdateRepository(
              VantaApiHttp(
                baseUri: Uri.https('api.vanta.test'),
                client: client,
                timeout: stop == 'timeout'
                    ? const Duration(milliseconds: 500)
                    : const Duration(seconds: 2),
              ),
            );
            addTearDown(updates.close);
            final symbols = ApiNotificationSymbolsRepository(
              VantaApiHttp(
                baseUri: Uri.https('api.vanta.test'),
                client: client,
                timeout: stop == 'timeout'
                    ? const Duration(milliseconds: 500)
                    : const Duration(seconds: 2),
              ),
            );
            addTearDown(symbols.close);
            final repository = ApiTradingHistoryRepository(api);
            final order =
                mapTradingHistory([historyOrder()], TradingHistoryTab.orders).single
                    as HistoryOrder;
            final position =
                mapTradingHistory([historyPosition()], TradingHistoryTab.positions).single
                    as HistoryPosition;
            var current = true;
            Future<void> run() async {
              switch (operation) {
                case 'orders':
                  await repository.read(TradingHistoryTab.orders, address: vantaTestAddress);
                case 'order fills':
                  await repository.readOrderFills(order, address: vantaTestAddress);
                case 'related orders':
                  await repository.readPositionOrders(position);
                case 'update check':
                  await updates.read('android');
                case 'income report':
                  await IncomeReportRepository(
                    api,
                    IncomeSource(),
                    () => vantaTestNow,
                  ).synchronize(vantaTestAddress);
                case 'notification units':
                  await symbols.read();
              }
            }

            final pending = RequestScope.runOwned(() => current, run);
            final failure = expectLater(
              pending,
              throwsA(
                transport.cause(
                  stop == 'timeout' ? ApiErrorCause.timeout : ApiErrorCause.cancelled,
                ),
              ),
            );
            await transport.turn();
            // A separate HTTP owner sharing this test transport remains usable even
            // when this feature/session is disposed.
            final otherHttp = VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: client);
            addTearDown(otherHttp.close);
            final other = otherHttp.get('/other');
            await transport.turn();
            final released = Completer<void>();
            final body = StreamController<List<int>>(onCancel: released.complete);
            if (headers) {
              client.responses[0].complete(http.StreamedResponse(body.stream, 200));
              body.add(utf8.encode('{'));
              await transport.turn();
            }
            if (stop == 'cancel') current = false;
            if (stop == 'dispose') {
              if (operation == 'notification units') {
                symbols.close();
              } else if (operation == 'update check') {
                updates.close();
              } else {
                api.close();
              }
            }
            // Complete the independent reader before the short timeout elapses.
            client.responses[1].complete(
              http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200),
            );
            expect(await other, {'ok': true});
            await failure;
            expect((client.requests[0] as http.Abortable).abortTrigger, completes);
            expect(client.requests, hasLength(2));
            // A loaded runner can hit the wall-clock timeout before headers (body never
            // read) or deliver the failure before the body cancel lands; either way the
            // body must end with no reader.
            if (headers && body.hasListener) {
              await released.future.timeout(const Duration(seconds: 2));
            }
            if (headers) expect(body.hasListener, isFalse);
            if (!headers) client.responses[0].complete(http.StreamedResponse(body.stream, 200));
            await transport.turn();
            await body.close();
          },
        );
      }
    }
  }
  test('unowned related read never dispatches', () async {
    final client = transport.Transport();
    final api = await transport.session(client);
    addTearDown(api.close);
    final p =
        mapTradingHistory([historyPosition()], TradingHistoryTab.positions).single
            as HistoryPosition;
    await expectLater(
      RequestScope.runOwned(
        () => false,
        () => ApiTradingHistoryRepository(api).readPositionOrders(p),
      ),
      throwsA(isA<VantaApiFailure>()),
    );
    expect(client.requests, isEmpty);
  });
}

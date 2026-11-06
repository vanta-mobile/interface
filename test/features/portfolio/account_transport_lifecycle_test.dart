import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/network/backend_http_pool.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final phase in ['/fapi/v3/time', AsterAccountService.accountPath, '/fapi/v3/exchangeInfo']) {
    test('account scope cancellation reaches transport during $phase', () async {
      var current = true, signatures = 0;
      final aborted = Completer<void>();
      final entered = Completer<void>(), late = Completer<http.StreamedResponse>();
      final body = StreamController<List<int>>();
      final calls = <String>[];
      final service = AsterAccountService(
        client: MockClient.streaming((request, bytes) async {
          await bytes.drain<void>();
          calls.add(request.url.path);
          if (request.url.path == phase) {
            (request as http.Abortable).abortTrigger!.then((_) => aborted.complete());
            entered.complete();
            return late.future;
          }
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode(
                  request.url.path.endsWith('/time')
                      ? {'serverTime': 1793620800123}
                      : accountPayload(),
                ),
              ),
            ),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final repository = SignedAccountRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        signatures++;
        return TestWalletConnection.signature;
      });
      final result = repository.read(
        address: accountAddress,
        isCurrent: () => current,
        onStep: (_) {},
      );
      final failure = expectLater(result, throwsA(isA<AccountReadFailure>()));
      await entered.future;
      current = false;
      await failure.timeout(const Duration(seconds: 1));
      await aborted.future.timeout(const Duration(seconds: 1));
      expect(signatures, phase.endsWith('/time') ? 0 : 1);
      expect(calls.last, phase);
      late.complete(http.StreamedResponse(body.stream, 200));
      await Future<void>.delayed(Duration.zero);
      await body.close();
    });
  }

  test('services share sockets while keeping decoders and close lifetimes separate', () async {
    var created = 0;
    final pool = BackendHttpPool(
      createClient: () {
        created++;
        return MockClient((_) async => http.Response('{"quantity":0.123456789123456789}', 200));
      },
    );
    final custom = AsterAccountService(
      client: pool.lease(),
      decodeResponse: (text) => {'exact': text},
    );
    final standard = AsterAccountService(client: pool.lease());
    addTearDown(() {
      custom.close();
      standard.close();
      pool.close();
    });
    expect(await custom.get('/custom'), {'exact': '{"quantity":0.123456789123456789}'});
    final decoded = await standard.get('/standard') as Map;
    expect(decoded['quantity'], isA<double>());
    custom.close();
    expect((await standard.get('/still-open') as Map)['quantity'], decoded['quantity']);
    expect(created, 1);
  });
}

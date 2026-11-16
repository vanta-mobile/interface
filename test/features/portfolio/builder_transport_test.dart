import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/network/backend_http_pool.dart';
import 'package:vanta/features/authorization/data/builder_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/builder_order_preflight.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/aster_signatures.dart';
import '../../support/builder.dart';
import '../../support/live_order.dart';

class _Transport extends http.BaseClient {
  _Transport(this.path);
  final String path;
  final started = Completer<void>();
  final response = Completer<http.StreamedResponse>();
  http.BaseRequest? held;
  int posts = 0, closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    if (request.method == 'POST') posts++;
    if (request.url.path == path && held == null) {
      held = request;
      started.complete();
      return response.future;
    }
    final Object payload;
    if (request.url.path.endsWith('/time')) {
      payload = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
    } else if (request.url.path.endsWith('/builder')) {
      payload = [
        {
          'userAddress': fixtureMaster,
          'builderAddress': VantaBuilder.address,
          'maxFeeRate': 0.0005,
        },
      ];
    } else {
      payload = {'symbol': 'BTCUSDT', 'makerCommissionRate': '0', 'takerCommissionRate': '0.0004'};
    }
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(payload))), 200);
  }

  @override
  void close() => closes++;
}

void main() {
  for (final path in ['/fapi/v3/builder', '/fapi/v3/commissionRate']) {
    for (final bodyStarted in [false, true]) {
      for (final dispose in [false, true]) {
        test(
          '$path aborts ${bodyStarted ? 'body' : 'headers'} on ${dispose ? 'disposal' : 'scope change'} without closing another consumer',
          () async {
            final transport = _Transport(path);
            final pool = BackendHttpPool(createClient: () => transport);
            final a = AsterAccountService(client: pool.lease()),
                b = AsterAccountService(client: pool.lease());
            addTearDown(() {
              a.close();
              b.close();
              pool.close();
            });
            final nonces = AsterReadNonces();
            AsterBuilderAuthorizationRepository builder(AsterAccountService service) =>
                AsterBuilderAuthorizationRepository(
                  service,
                  fixtureWalletSign,
                  nonces: nonces,
                  journal: MemoryBuilderApprovalJournal(),
                  authorization: builderTestAgent,
                );
            var current = true, cancelled = false;
            final pending = BuilderOrderPreflight(builder(a)).read(
              service: a,
              sign: fixtureWalletSign,
              nonces: nonces,
              authorization: builderTestAgent,
              intent: LiveOrderIntent(
                context: liveContext(address: fixtureMaster),
                draft: liveDraft(),
                clientOrderId: 'vanta-abort',
                revision: 0,
              ),
              isCurrent: () => current,
              canSubmit: () => true,
            );
            final failure = expectLater(pending, throwsA(isA<AccountReadFailure>()));
            await transport.started.future;
            final body = StreamController<List<int>>(onCancel: () => cancelled = true);
            if (bodyStarted) {
              transport.response.complete(http.StreamedResponse(body.stream, 200));
              body.add(utf8.encode('[{"partial":'));
              await Future<void>.delayed(Duration.zero);
            }
            if (dispose) {
              a.close();
            } else {
              current = false;
            }
            await failure;
            await (transport.held! as http.Abortable).abortTrigger;
            if (!bodyStarted) transport.response.complete(http.StreamedResponse(body.stream, 200));
            await Future<void>.delayed(Duration.zero);
            expect(cancelled, true);
            expect(transport.posts, 0);
            expect(transport.closes, 0);
            expect(
              (await builder(b).inspect(address: fixtureMaster, isCurrent: () => true)).sufficient,
              true,
            );
            await body.close();
          },
        );
      }
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/authorization/data/builder_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/builder_order_preflight.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import '../../support/aster_signatures.dart';
import '../../support/attached_order.dart';
import '../../support/builder.dart';
import '../../support/live_order.dart';

void main() {
  late AsterAccountService service;
  late AsterBuilderAuthorizationRepository builder;
  late SignedLiveOrderRepository repo;
  late LiveOrderIntent intent;
  late List<http.Request> requests;
  late bool current, canSend, approved, timeout, expireAfterSignature;
  late String maker, taker;
  Object? fees;
  setUp(() {
    current = canSend = approved = true;
    timeout = expireAfterSignature = false;
    maker = '0';
    taker = '0.0004';
    fees = null;
    requests = [];
    intent = LiveOrderIntent(
      context: liveContext(address: fixtureMaster),
      draft: liveDraft(),
      clientOrderId: 'vanta-builder-123',
      revision: 0,
    );
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/time')) {
          return http.Response(
            jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
            200,
          );
        }
        final params = r.method == 'GET' ? r.url.queryParameters : Uri.splitQueryString(r.body);
        final query = (r.method == 'GET' ? r.url.query : r.body).split('&signature=').first;
        expect(params['user'], fixtureMaster);
        expect(params['signer'], fixtureChild);
        expect(
          verifyAsterWalletSignature(fixtureChild, asterReadTypedData(query), params['signature']!),
          true,
        );
        switch (r.url.path) {
          case '/fapi/v3/builder':
            return http.Response(
              jsonEncode([
                if (approved)
                  {
                    'userAddress': fixtureMaster,
                    'builderAddress': VantaBuilder.address,
                    'maxFeeRate': 0.0005,
                  },
              ]),
              200,
            );
          case '/fapi/v3/commissionRate':
            return http.Response(
              jsonEncode(
                fees ??
                    {
                      'symbol': 'BTCUSDT',
                      'makerCommissionRate': maker,
                      'takerCommissionRate': taker,
                    },
              ),
              200,
            );
          case '/fapi/v3/positionRisk':
            return http.Response(jsonEncode(livePositionPayload(intent.context)), 200);
          case '/fapi/v3/order':
            if (r.method == 'POST') {
              if (timeout) throw TimeoutException('fixture');
              return http.Response('{"orderId":99}', 200);
            }
            return http.Response(jsonEncode(liveQueryPayload(intent)), 200);
          case '/fapi/v3/placeStrategyOrder':
            if (timeout) throw TimeoutException('fixture');
            return http.Response(jsonEncode(attachedQuery(intent)), 200);
          case '/fapi/v3/strategyOpenOrder':
          case '/fapi/v3/strategyHistoryOrder':
            return http.Response(jsonEncode(attachedQuery(intent)), 200);
          default:
            fail('Unexpected endpoint ${r.url.path}');
        }
      }),
    );
    final nonces = AsterReadNonces();
    builder = AsterBuilderAuthorizationRepository(
      service,
      fixtureWalletSign,
      nonces: nonces,
      journal: MemoryBuilderApprovalJournal(),
      authorization: builderTestAgent,
    );
    repo = SignedLiveOrderRepository(
      service,
      fixtureWalletSign,
      nonces: nonces,
      now: () => liveOrderClock,
      builder: BuilderOrderPreflight(builder),
      authorization: (owner) async {
        final agent = await builderTestAgent(owner);
        return AccountRequestIdentity(
          address: agent.address,
          sign: ({required expectedAddress, required typedData}) async {
            final signature = await agent.sign(
              expectedAddress: expectedAddress,
              typedData: typedData,
            );
            if (expireAfterSignature &&
                ((typedData['message'] as Map)['msg'] as String).contains('newClientOrderId=')) {
              canSend = false;
            }
            return signature;
          },
        );
      },
    );
    addTearDown(service.close);
  });
  Future<LiveOrderResult> submit() => repo.submit(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSend,
    onStep: (_) {},
  );
  for (final market in [false, true]) {
    test(
      'ordinary ${market ? 'market' : 'limit'} order signs attribution and the additional fee exactly once',
      () async {
        intent = LiveOrderIntent(
          context: intent.context,
          draft: liveDraft(market: market, price: market ? '' : '80000'),
          clientOrderId: intent.clientOrderId,
          revision: 0,
        );
        expect((await submit()).status, 'NEW');
        final post = requests.singleWhere((r) => r.method == 'POST');
        final p = Uri.splitQueryString(post.body);
        expect(p['builder'], VantaBuilder.address);
        expect(p['feeRate'], '0.0001');
        expect(p['type'], market ? 'MARKET' : 'LIMIT');
        expect(p['newClientOrderId'], intent.clientOrderId);
        expect(requests.where((r) => r.url.path.endsWith('/commissionRate')), hasLength(1));
      },
    );
  }
  test(
    'post-only strategy budgets protection legs and signs Builder fields at strategy level',
    () async {
      intent = attachedIntent(context: intent.context, policy: LiveOrderTimeInForce.postOnly);
      expect((await submit()).strategy, isNotNull);
      final post = requests.singleWhere((r) => r.method == 'POST');
      final p = Uri.splitQueryString(post.body);
      expect(post.url.path, '/fapi/v3/placeStrategyOrder');
      expect(p['feeRate'], '0.0001');
      expect(p['builder'], VantaBuilder.address);
      final legs = jsonDecode(p['subOrderList']!) as List;
      expect((legs.first as Map)['timeInForce'], 'GTX');
      expect(legs.every((l) => !(l as Map).containsKey('builder')), true);
    },
  );
  test('live revocation, malformed fees, and budget excess prevent every placement POST', () async {
    approved = false;
    await expectLater(
      submit(),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderAuthorizationRequired'),
      ),
    );
    approved = true;
    fees = {'symbol': 'BTCUSDT', 'takerCommissionRate': '0.0004'};
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
    );
    fees = null;
    taker = '0.001';
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderFeeAboveBudget')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('identity and submit guards prevent late signing from dispatching', () async {
    expireAfterSignature = true;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    current = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
  });
  test(
    'placement timeout queries the original ID without repeating POST or fee preflight',
    () async {
      timeout = true;
      expect((await submit()).status, 'NEW');
      await repo.recheck(intent: intent, isCurrent: () => current, onStep: (_) {});
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(requests.where((r) => r.url.path.endsWith('/commissionRate')), hasLength(1));
      final queries = requests.where((r) => r.method == 'GET' && r.url.path == '/fapi/v3/order');
      expect(queries, hasLength(2));
      expect(
        queries.every((r) => r.url.queryParameters['origClientOrderId'] == intent.clientOrderId),
        true,
      );
    },
  );
  test('an expired fee quote fails closed before dispatch', () {
    final q = BuilderOrderQuote(Decimal.zero, VantaBuilder.approvalCap, lifetime: Duration.zero);
    expect(
      q.checkFresh,
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderFeeQuoteExpired')),
    );
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  late LiveOrderIntent intent;
  late AsterAccountService service;
  late SignedLiveOrderRepository repository;
  late List<http.Request> requests;
  late List<String> signatures;
  late List<LiveOrderStep> steps;
  late bool current, canSend, postTimeout, openMissing, historyMissing;
  late int refusedAt, failureCode;
  late Object? query, positions;
  void Function(int)? afterSign;
  setUp(() {
    intent = attachedIntent();
    requests = [];
    signatures = [];
    steps = [];
    current = canSend = true;
    postTimeout = openMissing = historyMissing = false;
    refusedAt = failureCode = 0;
    query = attachedQuery(intent);
    positions = livePositionPayload(intent.context);
    afterSign = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.followRedirects, false);
        switch (request.url.path) {
          case '/fapi/v3/time':
            return http.Response(
              jsonEncode({'serverTime': liveOrderClock.millisecondsSinceEpoch}),
              200,
            );
          case '/fapi/v3/positionRisk':
            expect(request.method, 'GET');
            return http.Response(jsonEncode(positions), 200);
          case '/fapi/v3/placeStrategyOrder':
            expect(request.method, 'POST');
            expect(request.url.query, '');
            if (postTimeout) throw TimeoutException('fixture');
            return http.Response(
              jsonEncode({
                'failureCode': failureCode,
                'failureReason': 'must not be exposed',
                'strategyId': 999,
              }),
              200,
            );
          case '/fapi/v3/strategyOpenOrder':
            expect(request.method, 'GET');
            if (openMissing) return http.Response('{"code":-2013,"msg":"not found"}', 400);
            return http.Response(jsonEncode(query), 200);
          case '/fapi/v3/strategyHistoryOrder':
            expect(request.method, 'GET');
            if (historyMissing) return http.Response('{"code":-2013,"msg":"not found"}', 400);
            return http.Response(jsonEncode(query), 200);
          default:
            fail('Unexpected endpoint ${request.url.path}');
        }
      }),
    );
    repository = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        signatures.add((typedData['message'] as Map)['msg'] as String);
        if (signatures.length == refusedAt) throw const AuthFailure('authWalletRejected');
        afterSign?.call(signatures.length);
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => liveOrderClock,
    );
  });
  tearDown(() => service.close());
  Future<LiveOrderResult> submit() => repository.submit(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSend,
    onStep: steps.add,
  );
  Future<LiveOrderResult> check() =>
      repository.recheck(intent: intent, isCurrent: () => current, onStep: steps.add);
  List<http.Request> getSigned() => requests.where((r) => !r.url.path.endsWith('/time')).toList();

  for (final execution in AttachedExitExecution.values) {
    test('advanced exit signs exact terms and never replays after timeout $execution', () async {
      intent = attachedIntent(
        context: liveCloseContext(short: true, quantity: '0.002'),
        quantity: '0.003',
        protection: LiveOrderAttachment(
          takeProfit: AttachedExit(
            kind: LiveOrderTriggerKind.takeProfit,
            price: '81000',
            execution: execution,
            limitPrice: execution == AttachedExitExecution.manualLimit ? '80999.9' : null,
          ),
          stopLoss: const AttachedExit(
            kind: LiveOrderTriggerKind.stop,
            price: '79000',
            basis: LiveOrderTriggerBasis.last,
            execution: AttachedExitExecution.automaticLimit,
          ),
        ),
      );
      positions = livePositionPayload(intent.context);
      query = attachedQuery(intent);
      postTimeout = true;
      expect((await submit()).needsRecheck, false);
      final post = Uri.splitQueryString(signatures[1]);
      expect(post['user'], accountAddress);
      expect(post['signer'], accountAddress);
      final legs = jsonDecode(post['subOrderList']!) as List;
      final tp = legs[1] as Map, sl = legs[2] as Map;
      expect(tp['quantity'], '0.003');
      expect(
        tp['type'],
        execution == AttachedExitExecution.market ? 'TAKE_PROFIT_MARKET' : 'TAKE_PROFIT',
      );
      expect(tp['price'], switch (execution) {
        AttachedExitExecution.market => null,
        AttachedExitExecution.manualLimit => '80999.9',
        AttachedExitExecution.automaticLimit => '81000',
      });
      expect(sl['type'], 'STOP');
      expect(sl['price'], '79000');
      expect(sl['workingType'], 'CONTRACT_PRICE');
      expect(tp['firstDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
      expect(sl['secondDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
      expect(getSigned()[1].body, '${signatures[1]}&signature=${TestWalletConnection.signature}');
      await check();
      expect(requests.where((r) => r.method == 'POST').length, 1);
    });
  }

  test('compound BBO signs the zero sentinel and selected level with current EOA only', () async {
    intent = attachedIntent(peg: AttachedEntryPeg.queue20);
    query = attachedQuery(intent);
    expect((await submit()).needsRecheck, false);
    expect(signatures.length, 3);
    final post = Uri.splitQueryString(signatures[1]);
    final entry = (jsonDecode(post['subOrderList']!) as List).first as Map;
    expect(entry['price'], '0');
    expect(entry['pegPriceType'], 'QUEUE_20');
    expect(post['user'], accountAddress);
    expect(post['signer'], accountAddress);
    expect(getSigned().any((r) => r.url.path == '/fapi/v3/order'), false);
    expect(getSigned()[1].body, '${signatures[1]}&signature=${TestWalletConnection.signature}');
  });
  test('wrong BBO in query keeps original strategy unresolved until GET-only repair', () async {
    intent = attachedIntent(peg: AttachedEntryPeg.queue1);
    query = attachedQuery(intent);
    (((query as Map)['subOrders'] as List).first as Map)['pegPriceType'] = 'COUNTERPARTY_1';
    expect((await submit()).needsRecheck, true);
    query = attachedQuery(intent);
    expect((await check()).needsRecheck, false);
    expect(requests.where((r) => r.method == 'POST').length, 1);
    expect(Uri.splitQueryString(signatures.last)['clientStrategyId'], intent.clientOrderId);
  });
  test('BBO HTTP200 bracket rejection remains safe and unknown when query is absent', () async {
    intent = attachedIntent(peg: AttachedEntryPeg.counterparty3);
    failureCode = -4142;
    openMissing = historyMissing = true;
    final result = await submit();
    expect(result.needsRecheck, true);
    expect(result.failure!.key, 'attachedOrderRejected');
    expect(result.failure!.code, -4142);
    expect(result.strategy, null);
    await check();
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('BBO POST timeout can be resolved only by matching original peg query', () async {
    intent = attachedIntent(peg: AttachedEntryPeg.counterparty5);
    query = attachedQuery(intent);
    postTimeout = true;
    expect((await submit()).needsRecheck, false);
    await check();
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('invalid market BBO cannot request signatures or submit', () async {
    intent = attachedIntent(peg: AttachedEntryPeg.queue1, market: true);
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'attachedEntryPegInvalid')),
    );
    expect(signatures, isEmpty);
    expect(requests, isEmpty);
  });
  test('three same-wallet signatures, exact body bytes and linked suborders', () async {
    final result = await submit();
    expect(result.orderId, null);
    expect(result.strategy!.strategyId, '9876');
    expect(result.needsRecheck, false);
    expect(signatures.length, 3);
    final signed = getSigned();
    expect(signed.map((r) => r.url.path), [
      '/fapi/v3/positionRisk',
      '/fapi/v3/placeStrategyOrder',
      '/fapi/v3/strategyOpenOrder',
    ]);
    for (var i = 0; i < signed.length; i++) {
      final bytes = signed[i].method == 'POST' ? signed[i].body : signed[i].url.query;
      expect(bytes, '${signatures[i]}&signature=${TestWalletConnection.signature}');
      final params = Uri.splitQueryString(signatures[i]);
      expect(params['user'], accountAddress);
      expect(params['signer'], accountAddress);
      expect(params['nonce'], '${liveOrderClock.millisecondsSinceEpoch * 1000 + i}');
    }
    final post = Uri.splitQueryString(signatures[1]);
    expect(post['clientStrategyId'], 'vanta-strategy-123');
    expect(post['strategyType'], 'OTOCO');
    expect(post.containsKey('newClientOrderId'), false);
    final legs = jsonDecode(post['subOrderList']!) as List;
    expect(legs[0], {
      'strategySubId': '1',
      'securityType': 'USDT_FUTURES',
      'symbol': 'BTCUSDT',
      'side': 'BUY',
      'positionSide': 'BOTH',
      'type': 'LIMIT',
      'quantity': '0.001',
      'clientOrderId': 'vanta-strategy-123-1',
      'price': '80000',
      'timeInForce': 'GTC',
    });
    expect((legs[1] as Map)['firstDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
    expect((legs[1] as Map)['secondDrivenId'], '3');
    final query = Uri.splitQueryString(signatures[2]);
    expect(query['clientStrategyId'], 'vanta-strategy-123');
    expect(query['strategyType'], 'OTOCO');
    expect(query.containsKey('orderId'), false);
    expect(query.containsKey('strategyId'), false);
    expect(
      steps,
      containsAllInOrder([
        LiveOrderStep.signingPosition,
        LiveOrderStep.signing,
        LiveOrderStep.submitting,
        LiveOrderStep.checkSigning,
      ]),
    );
  });
  test(
    'POST timeout followed by exact query resolves without ordinary endpoint or resubmission',
    () async {
      postTimeout = true;
      expect((await submit()).needsRecheck, false);
      await check();
      expect(requests.where((r) => r.method == 'POST').length, 1);
      expect(requests.any((r) => r.url.path == '/fapi/v3/order'), false);
      expect(Uri.splitQueryString(signatures.last)['clientStrategyId'], 'vanta-strategy-123');
    },
  );
  test('open strategy missing falls back to independently signed same-ID history', () async {
    openMissing = true;
    (query as Map)['strategyStatus'] = 'EXPIRED';
    final result = await submit();
    expect(result.strategy!.status, 'EXPIRED');
    expect(signatures.length, 4);
    expect(getSigned().last.url.path, '/fapi/v3/strategyHistoryOrder');
    final a = Uri.splitQueryString(signatures[2]), b = Uri.splitQueryString(signatures[3]);
    expect(b['clientStrategyId'], a['clientStrategyId']);
    expect(b['strategyType'], a['strategyType']);
    expect(a['nonce'], isNot(b['nonce']));
  });
  test('HTTP200 failureCode and absent open/history never report accepted', () async {
    failureCode = -4142;
    openMissing = historyMissing = true;
    final result = await submit();
    expect(result.needsRecheck, true);
    expect(result.strategy, null);
    expect(result.failure!.key, 'attachedOrderRejected');
    expect(result.failure!.code, -4142);
    await check();
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('failed ACK cannot override later verified strategy', () async {
    failureCode = -4142;
    final result = await submit();
    expect(result.failure, null);
    expect(result.strategy!.strategyId, '9876');
  });
  for (final signature in [1, 2, 3]) {
    test('refusing signature $signature preserves send boundary', () async {
      refusedAt = signature;
      if (signature < 3) {
        await expectLater(
          submit(),
          throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
        );
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
      } else {
        expect((await submit()).needsRecheck, true);
        expect(requests.where((r) => r.method == 'POST').length, 1);
      }
    });
  }
  test('changed position before POST refuses attached quantity and stops signatures', () async {
    ((positions as List).first as Map)['positionAmt'] = '-0.001';
    ((positions as List).first as Map)['entryPrice'] = '79000';
    await expectLater(
      submit(),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'attachedOrderPositionChanged'),
      ),
    );
    expect(signatures.length, 1);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  for (final stage in [1, 2]) {
    test('expired configuration or confirmation after signature $stage cannot POST', () async {
      afterSign = (n) {
        if (n == stage) canSend = false;
      };
      await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  test('late signature from changed wallet cannot cross POST boundary', () async {
    afterSign = (n) {
      if (n == 2) current = false;
    };
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('wrong linkage keeps unknown frozen, query-only recovery can resolve it', () async {
    (((query as Map)['subOrders'] as List)[1] as Map)['secondDrivenOn'] = 'NEW';
    expect((await submit()).needsRecheck, true);
    query = attachedQuery(intent);
    expect((await check()).needsRecheck, false);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('history signature refusal is unresolved and does not create a new strategy', () async {
    openMissing = true;
    refusedAt = 4;
    expect((await submit()).needsRecheck, true);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
}

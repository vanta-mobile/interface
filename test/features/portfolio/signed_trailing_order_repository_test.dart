import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/wallet_connection.dart';

void main() {
  late List<http.Request> requests;
  late List<String> messages;
  late AsterAccountService service;
  late SignedLiveOrderRepository repository;
  late LiveOrderIntent intent;
  late Map<String, dynamic> payload;
  late bool postTimeout, changedPosition, canSend;
  late int rejected;
  void Function()? afterSign;
  setUp(() {
    requests = [];
    messages = [];
    rejected = 0;
    postTimeout = changedPosition = false;
    canSend = true;
    afterSign = null;
    intent = liveIntent(market: true, trailing: const LiveOrderTrailing(callbackRate: '1.25'));
    payload = liveQueryPayload(intent);
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.followRedirects, false);
        Object data;
        if (request.url.path.endsWith('/time')) {
          data = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
        } else if (request.url.path.endsWith('/positionRisk')) {
          final positions = livePositionPayload(intent.context);
          if (changedPosition) positions.first['positionAmt'] = '0.02';
          data = positions;
        } else {
          expect(request.url.path, '/fapi/v3/order');
          if (request.method == 'POST') {
            if (postTimeout) throw TimeoutException('simulated');
            data = {'orderId': 999, 'status': 'FILLED'};
          } else {
            expect(request.method, 'GET');
            data = payload;
          }
        }
        return http.Response(jsonEncode(data), 200);
      }),
    );
    repository = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (messages.length == rejected) throw const AccountReadFailure('authWalletRejected');
        afterSign?.call();
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => liveOrderClock,
    );
  });
  tearDown(() => service.close());
  Future<LiveOrderResult> submit() => repository.submit(
    intent: intent,
    isCurrent: () => true,
    canSubmit: () => canSend,
    onStep: (_) {},
  );
  Future<LiveOrderResult> recheck() =>
      repository.recheck(intent: intent, isCurrent: () => true, onStep: (_) {});

  for (final explicit in [false, true]) {
    test('exact trailing POST then independent query, explicit activation=$explicit', () async {
      intent = liveIntent(
        market: true,
        trailing: LiveOrderTrailing(
          callbackRate: '1.25',
          activationPrice: explicit ? '79000' : null,
          basis: LiveOrderTriggerBasis.mark,
        ),
      );
      payload = liveQueryPayload(intent);
      expect((await submit()).status, 'NEW');
      final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
      expect(orders.map((r) => r.method), ['POST', 'GET']);
      final params = Uri.splitQueryString(orders.first.body);
      expect(params['user'], accountAddress);
      expect(params['signer'], accountAddress);
      expect(params['type'], 'TRAILING_STOP_MARKET');
      expect(params['callbackRate'], '1.25');
      expect(params['workingType'], 'MARK_PRICE');
      expect(params['activationPrice'], explicit ? '79000' : null);
      for (final key in ['price', 'stopPrice', 'priceProtect', 'timeInForce', 'closePosition']) {
        expect(params.containsKey(key), false);
      }
      expect(orders.first.body.split('&signature=').first, messages.first);
      expect(orders.last.url.query.split('&signature=').first, messages.last);
      expect(orders.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
      expect(params['nonce'], isNot(orders.last.url.queryParameters['nonce']));
      expect(messages.length, 2);
    });
  }
  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      test('trailing close keeps original side and rechecks position $short $hedge', () async {
        intent = liveCloseIntent(
          short: short,
          hedge: hedge,
          trailing: const LiveOrderTrailing(callbackRate: '5'),
        );
        payload = liveQueryPayload(intent, status: 'FILLED');
        expect((await submit()).status, 'FILLED');
        final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
        expect(signed.map((r) => r.method), ['GET', 'POST', 'GET']);
        expect(signed.first.url.path, '/fapi/v3/positionRisk');
        final params = Uri.splitQueryString(signed[1].body);
        expect(params['side'], short ? 'BUY' : 'SELL');
        expect(params['positionSide'], intent.positionSide);
        expect(params['quantity'], '0.005');
        expect(params['reduceOnly'], hedge ? null : 'true');
        expect(messages.length, 3);
      });
    }
  }
  test('timeout plus callback mismatch preserves query-only recovery', () async {
    postTimeout = true;
    payload = {...payload, 'priceRate': '1.3'};
    expect((await submit()).needsRecheck, true);
    payload = liveQueryPayload(intent, status: 'FILLED');
    expect((await recheck()).status, 'FILLED');
    final orders = requests.where((r) => r.url.path.endsWith('/order')).toList();
    expect(orders.map((r) => r.method), ['POST', 'GET', 'GET']);
    expect(orders.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
    expect(Uri.splitQueryString(orders.first.body)['callbackRate'], '1.25');
  });
  test('position change prevents trailing close POST', () async {
    intent = liveCloseIntent(trailing: const LiveOrderTrailing(callbackRate: '1'));
    changedPosition = true;
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveClosePositionChanged')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('invalid callback never prompts or sends', () async {
    intent = liveIntent(market: true, trailing: const LiveOrderTrailing(callbackRate: '5.1'));
    await expectLater(
      submit(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveTrailingRateInvalid')),
    );
    expect(requests, isEmpty);
    expect(messages, isEmpty);
  });
  test('refused signing never sends trailing POST', () async {
    rejected = 1;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('late signature cannot pass expired submission boundary', () async {
    afterSign = () => canSend = false;
    await expectLater(submit(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_live_order_repository.dart';
import 'package:vanta/features/portfolio/data/signed_quick_order_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/position_leverage.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedQuickOrderRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? fee, orders, brackets;
  late bool current, timeout, wrongFlags;
  late int reject;
  late LiveOrderIntent intent;
  void Function()? afterSign;
  setUp(() {
    requests = [];
    messages = [];
    current = true;
    timeout = wrongFlags = false;
    reject = 0;
    afterSign = null;
    fee = {'symbol': 'BTCUSDT', 'takerCommissionRate': '0.0004'};
    orders = [];
    brackets = leverageBrackets();
    intent = LiveOrderIntent(
      context: liveContext(),
      draft: liveDraft(market: true, price: '', quickEntry: true),
      clientOrderId: 'vanta-quick-123',
      revision: 0,
    );
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        expect(r.followRedirects, false);
        expect(r.url.host, 'fapi.asterdex.com');
        Object? payload;
        if (r.url.path.endsWith('/time')) {
          payload = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
        } else if (r.url.path.endsWith('/commissionRate')) {
          payload = fee;
        } else if (r.url.path.endsWith('/leverageBrackets')) {
          payload = brackets;
        } else if (r.url.path.endsWith('/openOrders')) {
          payload = orders;
        } else {
          expect(r.url.path, '/fapi/v3/order');
          if (r.method == 'POST') {
            if (timeout) throw TimeoutException('mock');
            payload = {'orderId': 999, 'status': 'FILLED'};
          } else {
            payload = {...liveQueryPayload(intent), if (wrongFlags) 'reduceOnly': true};
          }
        }
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    repository = SignedQuickOrderRepository(service, ({
      required expectedAddress,
      required typedData,
    }) async {
      expect(expectedAddress, accountAddress);
      messages.add((typedData['message'] as Map)['msg'] as String);
      if (messages.length == reject) throw const AccountReadFailure('authWalletRejected');
      afterSign?.call();
      return TestWalletConnection.signature;
    }, nonces: AsterReadNonces());
  });
  tearDown(() => service.close());
  Future<void> read() async {
    await repository.readSizing(context: liveContext(), isCurrent: () => current, onStep: (_) {});
  }

  test(
    'three independent signed reads use same EOA, exact bytes, symbol and unique nonces',
    () async {
      await read();
      final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
      expect(signed.map((r) => r.url.path), [
        '/fapi/v3/commissionRate',
        '/fapi/v3/leverageBrackets',
        '/fapi/v3/openOrders',
      ]);
      expect(messages.length, 3);
      for (var i = 0; i < signed.length; i++) {
        expect(signed[i].method, 'GET');
        expect(signed[i].url.query.split('&signature=').first, messages[i]);
        expect(signed[i].url.queryParameters['user'], accountAddress);
        expect(signed[i].url.queryParameters['signer'], accountAddress);
        expect(signed[i].url.queryParameters['symbol'], 'BTCUSDT');
      }
      expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 3);
    },
  );
  for (final invalid in <Object?>[null, 0.0004, 'NaN', '-0.0001', '1', '1e-4']) {
    test('fee $invalid rejected without further reads', () async {
      fee = {'symbol': 'BTCUSDT', 'takerCommissionRate': invalid};
      await expectLater(
        read(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
      );
      expect(messages.length, 1);
    });
  }
  test('wrong symbol and malformed pending orders cannot supply percentages', () async {
    fee = {'symbol': 'ETHUSDT', 'takerCommissionRate': '0.0004'};
    await expectLater(read(), throwsA(isA<AccountReadFailure>()));
    fee = {'symbol': 'BTCUSDT', 'takerCommissionRate': '0.0004'};
    orders = {};
    await expectLater(read(), throwsA(isA<AccountReadFailure>()));
  });
  for (final signature in [1, 2, 3]) {
    test('refused sizing signature $signature stops further reads', () async {
      reject = signature;
      await expectLater(read(), throwsA(isA<AccountReadFailure>()));
      expect(messages.length, signature);
    });
    test('identity changed on sizing signature $signature discards response', () async {
      afterSign = () {
        if (messages.length == signature) current = false;
      };
      await expectLater(read(), throwsA(isA<AccountReadFailure>()));
      expect(messages.length, signature);
    });
  }
  for (final hedge in [false, true]) {
    test('quick POST has explicit one-way false or omitted hedge reduction $hedge', () async {
      intent = LiveOrderIntent(
        context: liveContext(mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay),
        draft: liveDraft(market: true, price: '', quickEntry: true, buy: false),
        clientOrderId: 'vanta-quick-1',
        revision: 0,
      );
      final repo = SignedLiveOrderRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          messages.add((typedData['message'] as Map)['msg'] as String);
          return TestWalletConnection.signature;
        },
        nonces: AsterReadNonces(),
        now: () => liveOrderClock,
      );
      expect(
        (await repo.submit(
          intent: intent,
          isCurrent: () => true,
          canSubmit: () => true,
          onStep: (_) {},
        )).status,
        'NEW',
      );
      final post = requests.singleWhere((r) => r.method == 'POST');
      final params = Uri.splitQueryString(post.body);
      expect(params['type'], 'MARKET');
      expect(params['side'], 'SELL');
      expect(params['reduceOnly'], hedge ? null : 'false');
      expect(params['positionSide'], hedge ? 'SHORT' : 'BOTH');
      for (final key in ['price', 'stopPrice', 'timeInForce', 'callbackRate', 'closePosition']) {
        expect(params.containsKey(key), false);
      }
      expect(post.body.split('&signature=').first, messages.first);
    });
  }
  test('quick timeout or wrong reduction flags stays original-ID GET only', () async {
    final repo = SignedLiveOrderRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      nonces: AsterReadNonces(),
      now: () => liveOrderClock,
    );
    timeout = wrongFlags = true;
    expect(
      (await repo.submit(
        intent: intent,
        isCurrent: () => true,
        canSubmit: () => true,
        onStep: (_) {},
      )).needsRecheck,
      true,
    );
    wrongFlags = false;
    expect(
      (await repo.recheck(intent: intent, isCurrent: () => true, onStep: (_) {})).status,
      'NEW',
    );
    final list = requests.where((r) => r.url.path.endsWith('/order')).toList();
    expect(list.map((r) => r.method), ['POST', 'GET', 'GET']);
    expect(list.last.url.queryParameters['origClientOrderId'], intent.clientOrderId);
  });
}

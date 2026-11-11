import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/position_margin_mapper.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_main_order_capacity_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_revaluation.dart';
import '../../support/position_leverage.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedMainOrderCapacityRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late LiveOrderContext context;
  late Map<String, dynamic> account;
  late Object? orders, remaining, risks, commission;
  late bool current, multi, dual;
  late int reject;
  late DateTime clock;
  late int metadataPadding;
  String? malformedAt;
  void Function()? afterSign;
  void Function(http.Request)? afterHttp;
  Matcher failure(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'safe failure', key));
  setUp(() {
    metadataPadding = 0;
    malformedAt = null;
    requests = [];
    messages = [];
    context = capacityContext();
    account = capacityAccountPayload();
    orders = [];
    commission = {'symbol': 'BTCUSDT', 'takerCommissionRate': '0.0004'};
    remaining = {'remainingOpenableNotionalValue': '-1'};
    risks = [
      {
        ...leverageBrackets(),
        'brackets': [
          {
            'bracket': 1,
            'initialLeverage': 100,
            'notionalFloor': 0,
            'notionalCap': 10000,
            'maintMarginRatio': '0.005',
            'cum': '0',
          },
          {
            'bracket': 2,
            'initialLeverage': 50,
            'notionalFloor': 10000,
            'notionalCap': 100000,
            'maintMarginRatio': '0.01',
            'cum': '50',
          },
        ],
      },
    ];
    current = true;
    multi = dual = false;
    reject = 0;
    clock = liveOrderClock;
    afterSign = null;
    afterHttp = null;
    service = AsterAccountService(
      decodeResponse: decodePositionMarginJson,
      client: MockClient((r) async {
        requests.add(r);
        expect(r.method, 'GET');
        expect(r.url.origin, 'https://fapi.asterdex.com');
        expect(r.followRedirects, false);
        expect(r.body, isEmpty);
        if (r.url.path == malformedAt) return http.Response('invalid json', 200);
        Object? payload;
        switch (r.url.path) {
          case '/fapi/v3/time':
            payload = {'serverTime': liveOrderClock.millisecondsSinceEpoch};
          case '/fapi/v3/exchangeInfo':
            payload = {
              'metadata': 'x' * metadataPadding,
              'symbols': [
                for (final e in capacityUnits().entries)
                  {
                    'symbol': e.key,
                    'baseAsset': e.value.base,
                    'quoteAsset': e.value.quote,
                    'marginAsset': e.value.margin,
                  },
              ],
            };
          case '/fapi/v3/multiAssetsMargin':
            payload = {'multiAssetsMargin': multi};
          case '/fapi/v3/positionSide/dual':
            payload = {'dualSidePosition': dual};
          case '/fapi/v3/accountWithJoinMargin':
            payload = account;
          case '/fapi/v3/openOrders':
            payload = orders;
          case '/fapi/v3/commissionRate':
            payload = commission;
          case '/fapi/v3/leverageBrackets':
            payload = risks;
          case '/fapi/v3/remainingOpenableNotionalValue':
            payload = remaining;
          case '/fapi/v1/assetIndex':
            payload = [
              {
                'symbol': 'USDTUSD',
                'index': '1',
                'bidRate': '1',
                'askRate': '1',
                'time': liveOrderClock.millisecondsSinceEpoch,
              },
            ];
          default:
            throw StateError('unexpected endpoint');
        }
        afterHttp?.call(r);
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    repository = SignedMainOrderCapacityRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (messages.length == reject) throw const AccountReadFailure('authWalletRejected');
        afterSign?.call();
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => clock,
    );
  });
  tearDown(() => service.close());
  Future<void> read() async {
    await repository.read(context: context, isCurrent: () => current, onStep: (_) {});
  }

  test(
    'six signed GETs use the same EOA and exact query bytes; cap is separately anonymous',
    () async {
      final result = await repository.read(
        context: context,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.context, same(context));
      expect(result.marketFacts!.riskTiers.keys, ['BTCUSDT']);
      expect(result.marketFacts!.orders.orders, isEmpty);
      expect(result.availableMargin, Decimal.fromInt(100).toRational());
      final signed = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
      expect(signed.map((r) => r.url.path), [
        '/fapi/v3/multiAssetsMargin',
        '/fapi/v3/positionSide/dual',
        '/fapi/v3/accountWithJoinMargin',
        '/fapi/v3/openOrders',
        '/fapi/v3/leverageBrackets',
        '/fapi/v3/commissionRate',
      ]);
      expect(messages.length, 6);
      expect(requests.where((r) => r.url.path.endsWith('/time')).length, 1);
      expect(result.marketFacts!.takerFee, Decimal.parse('0.0004'));
      for (var i = 0; i < signed.length; i++) {
        final p = signed[i].url.queryParameters;
        expect(signed[i].url.query.split('&signature=').first, messages[i]);
        expect(p['user'], accountAddress);
        expect(p['signer'], accountAddress);
        expect(p['symbol'], i == 5 ? 'BTCUSDT' : null);
      }
      expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 6);
      final cap = requests.singleWhere(
        (r) => r.url.path.endsWith('/remainingOpenableNotionalValue'),
      );
      expect(cap.url.queryParameters, {'symbol': 'BTCUSDT', 'leverage': '10'});
      for (final r in requests.where((r) => !signed.contains(r))) {
        expect(
          r.url.queryParameters.keys.toSet().intersection({'user', 'signer', 'nonce', 'signature'}),
          isEmpty,
        );
      }
      expect(requests.any((r) => r.url.path.contains('assetIndex')), false);
    },
  );
  test('account-wide exchange metadata above 256 KB completes capacity read', () async {
    metadataPadding = 900000;
    ((risks as List).first['brackets'] as List).last['cum'] = '49.99';
    for (final row in ((risks as List).first as Map)['brackets'] as List) {
      row['initialLeverage'] = '${row['initialLeverage']}';
      row['bracket'] = '${row['bracket']}';
    }
    final snapshot = await repository.read(
      context: context,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(snapshot.context.symbol, 'BTCUSDT');
    expect(requests.any((r) => r.url.path.endsWith('/commissionRate')), true);
  });

  test('actual signed snapshot feeds both production liquidation previews', () async {
    final snapshot = await repository.read(
      context: context,
      isCurrent: () => current,
      onStep: (_) {},
    );
    final value = revalueMainOrderCapacity(
      snapshot: snapshot,
      marks: revaluationMarks({'BTCUSDT': '100'}),
      references: {'BTCUSDT': revaluationReference()},
      indices: null,
      now: clock,
    );
    final preview = MainOrderCapacityPreview(
      snapshot: snapshot,
      valuation: value,
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '2',
    );
    expect(preview.buy.liquidation, d('50.08') / d('1.99'));
    expect(preview.sell.liquidation, d('349.92') / d('2.01'));
    expect(requests.every((r) => r.method == 'GET'), true);
  });
  for (final invalid in <Object?>[
    null,
    {},
    {'symbol': 'ETHUSDT', 'takerCommissionRate': '0.001'},
    {'symbol': 'BTCUSDT', 'takerCommissionRate': 'invalid'},
    {'symbol': 'BTCUSDT', 'takerCommissionRate': '-0.001'},
    {'symbol': 'BTCUSDT', 'takerCommissionRate': '1'},
  ]) {
    test('invalid signed commission data fails safely: $invalid', () async {
      commission = invalid;
      await expectLater(
        read(),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.key, 'failure', 'accountDataInvalid')
              .having((e) => e.details?.cause, 'cause', ApiErrorCause.invalidResponse)
              .having((e) => e.details?.endpoint, 'endpoint', '/fapi/v3/commissionRate'),
        ),
      );
      expect(messages.length, 6);
    });
  }
  for (final endpoint in [
    '/fapi/v3/exchangeInfo',
    AsterAccountService.accountPath,
    '/fapi/v3/leverageBrackets',
    '/fapi/v3/commissionRate',
  ]) {
    test('malformed read response names $endpoint and never writes an order', () async {
      malformedAt = endpoint;
      await expectLater(
        read(),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.details?.cause, 'cause', ApiErrorCause.invalidResponse)
              .having((e) => e.details?.endpoint, 'endpoint', endpoint),
        ),
      );
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    });
  }

  test('numeric JSON commission is preserved by exact financial decoding', () async {
    commission = {'symbol': 'BTCUSDT', 'takerCommissionRate': 0.001};
    final snapshot = await repository.read(
      context: context,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(snapshot.marketFacts!.takerFee, Decimal.parse('0.001'));
  });
  for (var signature = 1; signature <= 6; signature++) {
    test('refusal at signature $signature stops all later signatures and GETs', () async {
      reject = signature;
      await expectLater(read(), failure('authWalletRejected'));
      expect(messages.length, signature);
      expect(
        requests.where((r) => r.url.queryParameters.containsKey('signature')).length,
        signature - 1,
      );
      expect(
        requests.any((r) => r.url.path.endsWith('/remainingOpenableNotionalValue')),
        signature == 6,
      );
    });
    test(
      'identity switch during signature $signature discards response before transmission',
      () async {
        afterSign = () {
          if (messages.length == signature) current = false;
        };
        await expectLater(read(), failure('authWalletChanged'));
        expect(messages.length, signature);
        expect(
          requests.where((r) => r.url.queryParameters.containsKey('signature')).length,
          signature - 1,
        );
      },
    );
    test('context expires during signature $signature before signed GET', () async {
      afterSign = () {
        if (messages.length == signature) clock = liveOrderClock.add(const Duration(seconds: 30));
      };
      await expectLater(read(), failure('liveOrderContextExpired'));
      expect(messages.length, signature);
      expect(
        requests.where((r) => r.url.queryParameters.containsKey('signature')).length,
        signature - 1,
      );
    });
  }
  test('retains account-wide orders and all occupied cross-symbol risk tiers', () async {
    (account['positions'] as List).add(
      capacityPosition(symbol: 'ETHUSDT', quantity: '1', orderMargin: '20'),
    );
    orders = [
      {...capacityOrder(), 'symbol': 'ETHUSDT'},
    ];
    (risks as List).add({...((risks as List).first as Map<String, dynamic>), 'symbol': 'ETHUSDT'});
    final result = await repository.read(
      context: context,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.marketFacts!.orders.orders.single.symbol, 'ETHUSDT');
    expect(result.marketFacts!.orders.orders.single.remainingQty, Decimal.fromInt(2));
    expect(result.marketFacts!.riskTiers.keys.toSet(), {'BTCUSDT', 'ETHUSDT'});
    expect(result.account.positions.length, 2);
    expect(messages.length, 6);
  });
  test('missing occupied cross-symbol risk tiers fails before public cap lookup', () async {
    (account['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
    await expectLater(read(), failure('accountDataInvalid'));
    expect(messages.length, 5);
    expect(requests.any((r) => r.url.path.endsWith('/remainingOpenableNotionalValue')), false);
  });
  test('symbol-scoped object is not accepted as complete account-wide risk data', () async {
    risks = (risks as List).single;
    await expectLater(read(), failure('accountDataInvalid'));
    expect(messages.length, 5);
  });
  test('duplicate symbol in account-wide risk response fails safely', () async {
    (risks as List).add((risks as List).single);
    await expectLater(read(), failure('accountDataInvalid'));
    expect(messages.length, 5);
  });
  test('changed asset mode stops after first signature', () async {
    multi = true;
    await expectLater(read(), failure('liveCapacityChanged'));
    expect(messages.length, 1);
  });
  test('changed position mode stops after second signature', () async {
    dual = true;
    await expectLater(read(), failure('liveCapacityChanged'));
    expect(messages.length, 2);
  });
  test('disabled trading and changed selected leverage stop before order/risk prompts', () async {
    account['canTrade'] = false;
    await expectLater(read(), failure('liveOrderTradingDisabled'));
    expect(messages.length, 3);
    messages.clear();
    requests.clear();
    account['canTrade'] = true;
    ((account['positions'] as List).single as Map)['leverage'] = '20';
    await expectLater(read(), failure('liveCapacityChanged'));
    expect(messages.length, 3);
  });
  test('unknown pending notional stops before the fifth risk signature', () async {
    orders = [capacityOrder(type: 'STOP_MARKET')];
    await expectLater(read(), failure('liveCapacityPendingUnknown'));
    expect(messages.length, 4);
    expect(requests.any((r) => r.url.path.endsWith('/leverageBrackets')), false);
  });
  test('missing or malformed cap never becomes unlimited', () async {
    remaining = {};
    await expectLater(read(), failure('accountDataInvalid'));
    expect(messages.length, 5);
  });
  test('HTTP200 negative cap code remains a safe error', () async {
    remaining = {'code': -4028, 'msg': 'raw sensitive payload'};
    await expectLater(read(), failure('accountReadFailed'));
    expect(messages.length, 5);
  });
  test(
    'multi-asset mode adds only the public asset index and uses exact converted budget',
    () async {
      multi = true;
      context = capacityContext(assetMode: FuturesAssetMode.multi);
      final result = await repository.read(
        context: context,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.availableMargin, Decimal.fromInt(95).toRational());
      expect(
        requests.singleWhere((r) => r.url.path.endsWith('/assetIndex')).url.queryParameters,
        isEmpty,
      );
      expect(messages.length, 6);
    },
  );
  for (final path in ['/fapi/v3/exchangeInfo', '/fapi/v3/remainingOpenableNotionalValue']) {
    test('identity change during anonymous $path cancels dependent work', () async {
      afterHttp = (r) {
        if (r.url.path == path) current = false;
      };
      await expectLater(read(), failure('authWalletChanged'));
      expect(messages.length, path.endsWith('/exchangeInfo') ? 0 : 5);
    });
  }
  test('stale context and missing funds start no HTTP or wallet requests', () async {
    clock = liveOrderClock.add(const Duration(seconds: 30));
    await expectLater(read(), failure('liveOrderContextExpired'));
    clock = liveOrderClock;
    context = liveContext(withFunds: false);
    await expectLater(read(), failure('liveOrderReadFunds'));
    expect(requests, isEmpty);
    expect(messages, isEmpty);
  });
}

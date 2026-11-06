import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/capacity_account_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/main_order_margin_budget.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

Matcher failure(String key) =>
    throwsA(isA<AccountReadFailure>().having((f) => f.key, 'safe key', key));

void main() {
  test('single cross uses margin-asset balance, never USDT summary or wallet balance', () {
    final result = assembledCapacity();
    expect(result.availableMargin, Decimal.fromInt(100).toRational());
    expect(result.context, isNotNull);
    expect(result.contractCap.unlimited, true);
    expect(result.calculator(liveDraft()).rule, same(result.context.rules.limitQuantity));
    expect(
      result.calculator(liveDraft(market: true)).rule,
      same(result.context.rules.marketQuantity),
    );
  });
  test('isolated budget retains zero-position pending margin and other cross maintenance', () {
    final raw = capacityAccountPayload(isolated: true);
    ((raw['assets'] as List).single as Map)['availableBalance'] = '120';
    (raw['positions'] as List).addAll(<Map<String, dynamic>>[
      {...capacityPosition(symbol: 'ETHUSDT'), 'maintMargin': '30'},
      capacityPosition(symbol: 'SOLUSDT', isolated: true, orderMargin: '20'),
    ]);
    final result = assembledCapacity(
      context: capacityContext(isolated: true, payload: raw),
      payload: raw,
    );
    expect(result.availableMargin, Decimal.fromInt(100).toRational());
    expect(result.account.positions.last.quantity, Decimal.zero);
  });
  Map<String, dynamic> multiPayload({bool negative = false}) {
    final raw = capacityAccountPayload();
    raw['assets'] = [
      {...capacityAsset(), 'crossWalletBalance': '100', 'crossUnPnl': '10', 'initialMargin': '20'},
      {
        ...capacityAsset(asset: 'BNB'),
        'crossWalletBalance': negative ? '-2' : '2',
        'crossUnPnl': '0',
        'initialMargin': '0.1',
      },
    ];
    return raw;
  }

  for (final negative in [false, true]) {
    test('multi-asset budget uses eligible equity haircuts and margin ask rates $negative', () {
      final raw = multiPayload(negative: negative);
      final result = assembledCapacity(
        context: capacityContext(payload: raw, assetMode: FuturesAssetMode.multi),
        payload: raw,
        indices: capacityIndices(usdtAsk: '1.05'),
      );
      // USDT: min(110*1,110*1.05)-20*1.05=89.
      // BNB: positive 600-31=569; negative -620-31=-651.
      expect(
        result.availableMargin,
        Decimal.fromInt(negative ? -562 : 658) / Decimal.parse('1.05'),
      );
      expect(
        result.availableMargin * Decimal.parse('1.05').toRational(),
        Decimal.fromInt(negative ? -562 : 658).toRational(),
      );
    });
  }
  test('ineligible and explicitly zero-contribution assets need no invented rates', () {
    final raw = multiPayload();
    ((raw['assets'] as List).last as Map)['marginAvailable'] = false;
    final onlyUsdt = AssetIndexSnapshot(
      receivedAt: liveOrderClock,
      indices: {'USDTUSD': capacityIndices().forAsset('USDT')!},
    );
    final context = capacityContext(payload: raw, assetMode: FuturesAssetMode.multi);
    expect(
      assembledCapacity(context: context, payload: raw, indices: onlyUsdt).availableMargin,
      Decimal.fromInt(90).toRational(),
    );
    ((raw['assets'] as List).last as Map).addAll(<String, dynamic>{
      'marginAvailable': true,
      'crossWalletBalance': '0',
      'initialMargin': '0',
    });
    expect(
      assembledCapacity(context: context, payload: raw, indices: onlyUsdt).availableMargin,
      Decimal.fromInt(90).toRational(),
    );
  });
  for (final variant in ['missing', 'stale', 'future-snapshot', 'future-rate', 'missing-bnb']) {
    test('multi-asset $variant rates fail instead of returning a partial sum', () {
      final raw = multiPayload();
      AssetIndexSnapshot? indices = capacityIndices();
      if (variant == 'missing') indices = null;
      if (variant == 'stale') {
        indices = capacityIndices(time: liveOrderClock.subtract(const Duration(seconds: 90)));
      }
      if (variant == 'future-rate') {
        indices = capacityIndices(time: liveOrderClock.add(const Duration(seconds: 31)));
      }
      if (variant == 'future-snapshot') {
        indices = AssetIndexSnapshot(
          receivedAt: liveOrderClock.add(const Duration(seconds: 1)),
          indices: indices!.indices,
        );
      }
      if (variant == 'missing-bnb') {
        indices = AssetIndexSnapshot(
          receivedAt: liveOrderClock,
          indices: {'USDTUSD': indices!.forAsset('USDT')!},
        );
      }
      expect(
        () => assembledCapacity(
          context: capacityContext(payload: raw, assetMode: FuturesAssetMode.multi),
          payload: raw,
          indices: indices,
        ),
        failure('liveCapacityRatesUnavailable'),
      );
    });
  }
  test('multi-asset rejects isolated exposure including a zero-position retained wallet', () {
    final raw = multiPayload();
    (raw['positions'] as List).add({
      ...capacityPosition(symbol: 'ETHUSDT', isolated: true),
      'isolatedWallet': '-1',
    });
    expect(
      () => assembledCapacity(
        context: capacityContext(payload: raw, assetMode: FuturesAssetMode.multi),
        payload: raw,
        indices: capacityIndices(),
      ),
      failure('liveCapacityChanged'),
    );
  });
  test('pending ordinary LIMIT uses remaining amount and verified margin', () {
    final raw = capacityAccountPayload();
    ((raw['positions'] as List).single as Map)['openOrderInitialMargin'] = '20';
    final result = assembledCapacity(
      context: capacityContext(payload: raw),
      payload: raw,
      orders: [capacityOrder()],
    );
    expect(result.exposure.buyOrderNotional, Decimal.fromInt(200));
    expect(result.exposure.sellOrderNotional, Decimal.zero);
    expect(result.exposure.currentNotional, Decimal.fromInt(200));
  });
  test('account signed notional is retained separately from earlier public Mark', () {
    final raw = capacityAccountPayload();
    raw['positions'] = [
      {...capacityPosition(quantity: '2'), 'notional': '202'},
    ];
    final result = assembledCapacity(
      context: capacityContext(payload: raw),
      payload: raw,
    );
    expect(result.context.markPrice, Decimal.fromInt(100));
    expect(result.exposure.signedNotional, Decimal.fromInt(202));
    expect(result.exposure.currentNotional, Decimal.fromInt(202));
  });
  for (final type in [
    'MARKET',
    'STOP',
    'STOP_MARKET',
    'TAKE_PROFIT',
    'TRAILING_STOP_MARKET',
    'UNKNOWN',
  ]) {
    test('unverifiable pending $type cannot silently contribute zero exposure', () {
      expect(
        () => assembledCapacity(orders: [capacityOrder(type: type)]),
        failure('liveCapacityPendingUnknown'),
      );
    });
  }
  test('resolved ordinary peg still requires corroborated pending margin', () {
    expect(
      () => assembledCapacity(
        orders: [
          {...capacityOrder(), 'pegPriceType': 'QUEUE_1'},
        ],
      ),
      failure('liveCapacityChanged'),
    );
    expect(() => assembledCapacity(orders: [capacityOrder()]), failure('liveCapacityChanged'));
    final raw = capacityAccountPayload();
    ((raw['positions'] as List).single as Map)['openOrderInitialMargin'] = '20';
    expect(() => assembledCapacity(payload: raw), failure('liveCapacityChanged'));
  });
  test('closing-only conditional orders do not manufacture opening reservation', () {
    final result = assembledCapacity(
      orders: [capacityOrder(type: 'STOP_MARKET', reduceOnly: true)],
    );
    expect(result.exposure.currentNotional, Decimal.zero);
  });
  test('hedge risk includes both held sides and each pending opening side', () {
    final raw = capacityAccountPayload(hedge: true);
    raw['positions'] = [
      capacityPosition(side: 'LONG', quantity: '2', orderMargin: '20'),
      capacityPosition(side: 'SHORT', quantity: '-1', orderMargin: '30'),
    ];
    final result = assembledCapacity(
      context: capacityContext(hedge: true, payload: raw),
      payload: raw,
      orders: [
        capacityOrder(positionSide: 'LONG'),
        {...capacityOrder(side: 'SELL', positionSide: 'SHORT', quantity: '4'), 'orderId': 11},
        {...capacityOrder(side: 'SELL', positionSide: 'LONG', type: 'STOP_MARKET'), 'orderId': 12},
      ],
    );
    expect(result.exposure.hedge, true);
    expect(result.exposure.currentNotional, Decimal.fromInt(800));
  });
  test('known margin reporting precision permits a last-place quantum, not unknown orders', () {
    final raw = capacityAccountPayload();
    ((raw['positions'] as List).single as Map)['openOrderInitialMargin'] = '20.00000001';
    expect(
      assembledCapacity(payload: raw, orders: [capacityOrder()]).exposure.currentNotional,
      Decimal.fromInt(200),
    );
    ((raw['positions'] as List).single as Map)['openOrderInitialMargin'] = '20.00000002';
    expect(
      () => assembledCapacity(payload: raw, orders: [capacityOrder()]),
      failure('liveCapacityChanged'),
    );
  });
  test('account maxNotional and leverage-specific bracket cap both apply', () {
    final raw = capacityAccountPayload();
    ((raw['positions'] as List).single as Map)['maxNotional'] = '500';
    final context = capacityContext(payload: raw);
    expect(assembledCapacity(context: context, payload: raw).notionalCap, Decimal.fromInt(500));
    expect(
      assembledCapacity(
        context: context,
        payload: raw,
        brackets: [LeverageBracket(maximum: 20, floor: Decimal.zero, cap: Decimal.fromInt(400))],
      ).notionalCap,
      Decimal.fromInt(400),
    );
    expect(
      () => assembledCapacity(
        brackets: [LeverageBracket(maximum: 5, floor: Decimal.zero, cap: Decimal.fromInt(100000))],
      ),
      failure('liveCapacityChanged'),
    );
  });
  for (final (key, value) in <(String, Object)>[
    ('leverage', '20'),
    ('isolated', true),
    ('positionAmt', '1'),
    ('entryPrice', '101'),
  ]) {
    test('selected live context mismatch $key is rejected', () {
      final raw = capacityAccountPayload();
      if (key == 'entryPrice') raw['positions'] = [capacityPosition(quantity: '1')];
      final context = capacityContext(payload: raw);
      final row = (raw['positions'] as List).single as Map;
      row[key] = value;
      if (key == 'positionAmt') row['notional'] = '100';
      expect(
        () => assembledCapacity(context: context, payload: raw),
        failure('liveCapacityChanged'),
      );
    });
  }
  test(
    'missing selected zero rows, mismatched mode and trading disabled are concrete failures',
    () {
      final raw = capacityAccountPayload()..['positions'] = <dynamic>[];
      expect(() => assembledCapacity(payload: raw), failure('liveCapacityChanged'));
      expect(
        () => assembledCapacity(assetMode: FuturesAssetMode.multi),
        failure('liveCapacityChanged'),
      );
      expect(
        () => assembledCapacity(positionMode: FuturesPositionMode.hedge),
        failure('liveCapacityChanged'),
      );
      expect(
        () => assembledCapacity(payload: capacityAccountPayload()..['canTrade'] = false),
        failure('liveOrderTradingDisabled'),
      );
    },
  );
  for (final (symbol, leverage, offset) in [
    ('ETHUSDT', 10, 0),
    ('BTCUSDT', 20, 0),
    ('BTCUSDT', 10, -1),
    ('BTCUSDT', 10, 1),
  ]) {
    test('contract capacity scope $symbol $leverage $offset cannot cross contexts', () {
      final cap = SymbolOpenableNotional(
        symbol: symbol,
        leverage: leverage,
        receivedAt: liveOrderClock.add(Duration(seconds: offset)),
        remaining: Decimal.zero,
      );
      expect(() => assembledCapacity(contractCap: cap), failure('liveCapacityChanged'));
    });
  }
  for (final offset in [-1, 30]) {
    test('context expiry/backward clock $offset blocks all maxima', () {
      expect(
        () => assembledCapacity(now: liveOrderClock.add(Duration(seconds: offset))),
        failure('liveOrderContextExpired'),
      );
    });
  }
  test('USDT-only summary is never a substitute for a missing margin-asset row', () {
    final account = mapCapacityAccount(
      capacityAccountPayload()..['positions'] = <dynamic>[],
      address: accountAddress,
      receivedAt: liveOrderClock,
      units: capacityUnits(),
    );
    expect(
      () => mainOrderMarginBudget(
        account: account,
        marginAsset: 'UNKNOWN',
        assetMode: FuturesAssetMode.single,
        marginMode: PositionMarginMode.cross,
        indices: null,
        now: liveOrderClock,
      ),
      failure('accountDataInvalid'),
    );
  });
}

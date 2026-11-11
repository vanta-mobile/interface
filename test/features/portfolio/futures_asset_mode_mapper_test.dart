import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/futures_asset_mode_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/futures_asset_mode.dart';
import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';

import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

void main() {
  test('boolean read maps to single/multi with explicit string mutation parameters', () {
    expect(mapFuturesAssetMode({'multiAssetsMargin': false}), FuturesAssetMode.single);
    expect(mapFuturesAssetMode({'multiAssetsMargin': true}), FuturesAssetMode.multi);
    expect(FuturesAssetMode.single.parameter, 'false');
    expect(FuturesAssetMode.multi.parameter, 'true');
    for (final input in <Object?>[
      null,
      <Object?>[],
      <String, Object?>{},
      {'multiAssetsMargin': 'true'},
      {'multiAssetsMargin': 1},
    ]) {
      expect(() => mapFuturesAssetMode(input), throwsFormatException);
    }
  });
  test('cross exposure and zero isolated configuration are not active isolated positions', () {
    expect(mapAssetModeIsolatedSymbols([]), isEmpty);
    expect(
      mapAssetModeIsolatedSymbols([
        ...assetModeRows(quantity: '10'),
        ...assetModeRows(symbol: 'ETHUSDT', margin: 'isolated'),
      ]),
      isEmpty,
    );
  });
  test('tiny positions and both signs of retained isolated collateral block across symbols', () {
    final symbols = mapAssetModeIsolatedSymbols([
      ...assetModeRows(symbol: 'ZECUSDT', margin: 'isolated', quantity: '-0.000000000000000000001'),
      ...assetModeRows(symbol: 'ETHUSDT', margin: 'isolated', wallet: '-0.000000000000000000001'),
      ...assetModeRows(symbol: 'BTCUSDT', margin: 'isolated', wallet: '2'),
    ]);
    expect(symbols, ['BTCUSDT', 'ETHUSDT', 'ZECUSDT']);
    expect(() => symbols.add('XUSDT'), throwsUnsupportedError);
  });
  test('complete hedge rows share a mode and emit each isolated symbol once', () {
    expect(
      mapAssetModeIsolatedSymbols(assetModeRows(hedge: true, margin: 'isolated', quantity: '1')),
      ['BTCUSDT'],
    );
    expect(
      mapAssetModeIsolatedSymbols([
        for (final row in assetModeRows(hedge: true, margin: 'isolated'))
          {...row, 'positionAmt': '-0'},
      ]),
      isEmpty,
    );
  });
  test('duplicate, incomplete and conflicting hedge or account modes cannot certify safety', () {
    final net = assetModeRows().first, pair = assetModeRows(hedge: true);
    for (final data in [
      [net, net],
      [pair.first],
      [
        pair.first,
        {...pair.last, 'marginType': 'isolated'},
      ],
      [net, ...pair],
      [net, ...assetModeRows(symbol: 'ETHUSDT', hedge: true)],
      [
        {...pair.first, 'positionAmt': '-1'},
        pair.last,
      ],
      [
        pair.first,
        {...pair.last, 'positionAmt': '1'},
      ],
    ]) {
      expect(() => mapAssetModeIsolatedSymbols(data), throwsFormatException);
    }
  });
  test('bad symbols, missing fields, floating amounts and exponent strings fail even at zero', () {
    final row = assetModeRows().first;
    for (final payload in <Object?>[
      null,
      {},
      [null],
      [
        {...row, 'symbol': 'BTC&symbol=ETH'},
      ],
      [
        {...row, 'marginType': 'CROSSED'},
      ],
      [
        {...row, 'positionSide': null},
      ],
      [
        {...row, 'positionAmt': 0.0},
      ],
      [
        {...row, 'positionAmt': '1e-9'},
      ],
      [
        {...row, 'isolatedWallet': null},
      ],
      [
        {...row, 'isolatedWallet': 0.0},
      ],
    ]) {
      expect(() => mapAssetModeIsolatedSymbols(payload), throwsFormatException);
    }
  });

  test('empty isolated configuration still needs explicit Cross conversion', () {
    final markets = mapAssetModeMarkets(assetModeRows(margin: 'isolated'));
    expect(markets.single.requiresCross, true);
    expect(markets.single.blocked, false);
    final context = FuturesAssetModeContext(
      address: accountAddress,
      current: FuturesAssetMode.single,
      isolatedSymbols: const [],
      markets: markets,
      receivedAt: assetModeClock,
    );
    expect(context.blocks(FuturesAssetMode.multi), true);
    expect(() => markets.clear(), throwsUnsupportedError);
    expect(() => context.markets.clear(), throwsUnsupportedError);
  });
  test('orders-only isolated market is blocked, Cross exposure remains eligible', () {
    final orders = mapAsterOpenOrders(
      [openOrder()],
      address: accountAddress,
      receivedAt: assetModeClock,
    );
    final isolated = mapAssetModeMarkets(assetModeRows(margin: 'isolated'), orders: orders).single;
    expect(isolated.hasPosition, false);
    expect(isolated.openOrderCount, 1);
    expect(isolated.blocked, true);
    final cross = mapAssetModeMarkets(
      assetModeRows(quantity: '0.000000000000000001'),
      orders: orders,
    ).single;
    expect(cross.marginMode, PositionMarginMode.cross);
    expect(cross.requiresCross, false);
  });
  test('unknown order market and conflicting order side cannot certify readiness', () {
    for (final order in [openOrder(symbol: 'ETHUSDT'), openOrder(positionSide: 'LONG')]) {
      final orders = mapAsterOpenOrders(
        [order],
        address: accountAddress,
        receivedAt: assetModeClock,
      );
      expect(() => mapAssetModeMarkets(assetModeRows(), orders: orders), throwsFormatException);
    }
  });
  test('domain context copies blocker list and restricts only multi-assets target', () {
    final symbols = ['ETHUSDT'];
    final context = assetModeContext(isolatedSymbols: symbols);
    symbols.clear();
    expect(context.isolatedSymbols, ['ETHUSDT']);
    expect(context.blocks(FuturesAssetMode.multi), true);
    expect(context.blocks(FuturesAssetMode.single), false);
    expect(() => context.isolatedSymbols.clear(), throwsUnsupportedError);
  });
}

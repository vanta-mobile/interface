import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/position_card_metrics.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

const _address = '0x2222222222222222222222222222222222222222';
Decimal d(String value) => Decimal.parse(value);

PositionRisk position({
  String side = 'BOTH',
  String quantity = '0.01',
  bool isolated = false,
  String symbol = 'BTCUSDT',
}) => PositionRisk(
  symbol: symbol,
  side: side,
  quantity: d(quantity),
  entryPrice: d('80000'),
  markPrice: d('79000'),
  isolated: isolated,
  isolatedWallet: d(isolated ? '20' : '0'),
  leverage: 10,
  liquidationPrice: d('72000'),
  units: _usdt,
);

const _usdt = AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT');
const _bnb = AsterContractUnits(base: 'ETH', quote: 'BNB', margin: 'BNB');
final _now = DateTime.utc(2026, 11, 11, 12);

AsterAssetBalance asset(String name, String wallet, String pnl, {bool? margin = true}) =>
    AsterAssetBalance(
      asset: name,
      walletBalance: d(wallet),
      crossWalletBalance: d(wallet),
      crossUnrealizedProfit: d(pnl),
      marginAvailable: margin,
    );

AsterPosition row(
  String symbol, {
  bool? isolated = false,
  String maintenance = '1',
  AsterContractUnits? units = _usdt,
}) => AsterPosition(
  symbol: symbol,
  side: 'BOTH',
  quantity: d('1'),
  isolated: isolated,
  isolatedWallet: d('40'),
  unrealizedProfit: d('-10'),
  maintenanceMargin: d(maintenance),
  units: units,
);

AsterAccount account({
  String address = _address,
  List<AsterAssetBalance>? assets,
  List<AsterPosition>? positions,
}) => AsterAccount(
  address: address,
  receivedAt: _now,
  assets: assets ?? [asset('USDT', '120', '5'), asset('BNB', '2.5', '0')],
  positions:
      positions ??
      [
        row('BTCUSDT', maintenance: '1.4'),
        row('SOLUSDT', maintenance: '1'),
        // Isolated requirements stay out of the cross ratio.
        row('ETHUSDT', isolated: true, maintenance: '3'),
        row('ETHBNB', maintenance: '0.05', units: _bnb),
      ],
);

AssetIndexState rates({String bnbBid = '10', String bnbAsk = '12', DateTime? time}) =>
    AssetIndexState(
      checkedAt: _now,
      snapshot: AssetIndexSnapshot(
        receivedAt: _now,
        indices: {
          for (final (name, bid, ask) in [('USDT', '1', '1'), ('BNB', bnbBid, bnbAsk)])
            '${name}USD': AssetUsdIndex(
              symbol: '${name}USD',
              usd: d(ask),
              time: time ?? _now,
              bidRate: d(bid),
              askRate: d(ask),
            ),
        },
      ),
    );

AsterOpenOrder order({
  required String type,
  String side = 'SELL',
  String positionSide = 'BOTH',
  String stop = '90000',
  bool reduceOnly = true,
  bool closePosition = false,
  int minute = 0,
}) => AsterOpenOrder(
  symbol: 'BTCUSDT',
  orderId: '$type-$stop-$minute',
  side: side,
  positionSide: positionSide,
  type: type,
  status: 'NEW',
  time: DateTime.utc(2026, 11, 11, 12, minute),
  origQty: d(closePosition ? '0' : '0.005'),
  executedQty: Decimal.zero,
  price: Decimal.zero,
  stopPrice: d(stop),
  reduceOnly: reduceOnly,
  closePosition: closePosition,
);

void main() {
  group('positionMarginRatio', () {
    PositionRisk cross() => position(symbol: 'BTCUSDT');
    test('single-asset cross: margin-asset cross maintenance over its cross equity', () {
      // (1.4 + 1) / (120 + 5); isolated ETHUSDT and BNB-margined rows excluded.
      expect(
        positionMarginRatio(cross(), account(), _address, assetMode: FuturesAssetMode.single),
        d('1.92'),
      );
    });

    test('multi-asset cross: USD-converted requirements over converted equity', () {
      // (2.4 × 1 + 0.05 × 12) / (125 + min(2.5 × 12, 2.5 × 10)) = 3 / 150.
      expect(
        positionMarginRatio(
          cross(),
          account(),
          _address,
          assetMode: FuturesAssetMode.multi,
          rates: rates(),
        ),
        d('2'),
      );
    });

    test('multi-asset needs fresh rates and known eligibility', () {
      final p = cross();
      Decimal? ratio(AsterAccount a, AssetIndexState r) =>
          positionMarginRatio(p, a, _address, assetMode: FuturesAssetMode.multi, rates: r);
      expect(ratio(account(), rates(time: _now.subtract(const Duration(minutes: 5)))), isNull);
      expect(
        ratio(
          account(assets: [asset('USDT', '120', '5'), asset('BNB', '2.5', '0', margin: null)]),
          rates(),
        ),
        isNull,
      );
      // An ineligible asset with cross requirements cannot be converted.
      expect(
        ratio(
          account(assets: [asset('USDT', '120', '5'), asset('BNB', '2.5', '0', margin: false)]),
          rates(),
        ),
        isNull,
      );
    });

    test('isolated positions use their own wallet and unrealized PnL', () {
      final ratio = positionMarginRatio(
        position(symbol: 'ETHUSDT', isolated: true),
        account(),
        _address.toUpperCase(),
      );
      // 3 / (40 − 10).
      expect(ratio, d('10'));
    });

    test('unknown mode, missing terms or another wallet hide the cross ratio', () {
      final single = FuturesAssetMode.single;
      expect(positionMarginRatio(cross(), account(), _address), isNull);
      expect(positionMarginRatio(cross(), null, _address, assetMode: single), isNull);
      expect(
        positionMarginRatio(cross(), account(address: '0x1'), _address, assetMode: single),
        isNull,
      );
      expect(
        positionMarginRatio(
          cross(),
          account(positions: [row('BTCUSDT', isolated: null)]),
          _address,
          assetMode: single,
        ),
        isNull,
      );
      expect(positionMarginRatio(position(isolated: true), account(), _address), isNull);
    });
  });

  test('the needle starts at the arc end and points left near 16.7%', () {
    expect(marginGaugeRotation(Decimal.zero), moreOrLessEquals(-math.pi / 4));
    expect(marginGaugeRotation(d('50')), moreOrLessEquals(math.pi / 2));
    expect(marginGaugeRotation(d('100')), moreOrLessEquals(5 * math.pi / 4));
    expect(marginGaugeRotation(d('250')), moreOrLessEquals(5 * math.pi / 4));
  });

  group('liquidationProgress', () {
    test('measures the mark from entry toward liquidation, clamped', () {
      expect(
        liquidationProgress(entry: d('80000'), mark: d('78000'), liquidation: d('72000')),
        .25,
      );
      expect(liquidationProgress(entry: d('80000'), mark: d('81000'), liquidation: d('72000')), 0);
      expect(liquidationProgress(entry: d('80000'), mark: d('70000'), liquidation: d('72000')), 1);
      // Shorts liquidate above entry.
      expect(liquidationProgress(entry: d('100'), mark: d('105'), liquidation: d('120')), .25);
    });

    test('is unavailable without a positive liquidation price', () {
      expect(liquidationProgress(entry: d('80000'), mark: d('78000'), liquidation: null), isNull);
      expect(
        liquidationProgress(entry: d('80000'), mark: d('78000'), liquidation: Decimal.zero),
        isNull,
      );
    });
  });

  group('positionExitOrders', () {
    test('splits entire and partial TP/SL and keeps the newest of each', () {
      final exits = positionExitOrders(position(), [
        order(type: 'TAKE_PROFIT_MARKET', stop: '95000', closePosition: true, reduceOnly: false),
        order(type: 'STOP_MARKET', stop: '75000', closePosition: true, reduceOnly: false),
        order(type: 'TAKE_PROFIT', stop: '90000'),
        order(type: 'TAKE_PROFIT_MARKET', stop: '91000', minute: 5),
        order(type: 'STOP', stop: '76000'),
        // Not exits of this position.
        order(type: 'LIMIT', stop: '1'),
        order(type: 'STOP_MARKET', side: 'BUY', stop: '2'),
        order(type: 'STOP_MARKET', stop: '3', reduceOnly: false),
      ]);
      expect(exits.entireTakeProfit?.stopPrice, d('95000'));
      expect(exits.entireStopLoss?.stopPrice, d('75000'));
      expect(exits.partialTakeProfit?.stopPrice, d('91000'));
      expect(exits.partialStopLoss?.stopPrice, d('76000'));
      expect(exits.partialCount, 3);
    });

    test('hedge rows close their own side without reduce-only', () {
      final exits = positionExitOrders(position(side: 'SHORT', quantity: '-0.01'), [
        order(type: 'TAKE_PROFIT_MARKET', side: 'BUY', positionSide: 'SHORT', reduceOnly: false),
        order(type: 'STOP_MARKET', positionSide: 'LONG', reduceOnly: false),
      ]);
      expect(exits.partialTakeProfit, isNotNull);
      expect(exits.partialStopLoss, isNull);
      expect(exits.partialCount, 1);
    });
  });
}

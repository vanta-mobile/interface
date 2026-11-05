import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_funds_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_funds.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import '../../support/aster_account.dart';
import '../../support/live_order.dart';

void main() {
  Map<String, dynamic> payload({bool position = false}) => {
    ...accountPayload(),
    'canTrade': true,
    'positions': position
        ? [
            {
              'symbol': 'BTCUSDT',
              'positionSide': 'BOTH',
              'positionAmt': '0.01',
              'entryPrice': '79000',
              'leverage': '10',
              'isolated': false,
            },
          ]
        : <Map<String, dynamic>>[],
  };
  LiveOrderFunds map(
    Map<String, dynamic> data, {
    LiveOrderContext? context,
    FuturesAssetMode mode = FuturesAssetMode.single,
    PositionMarginMode marginMode = PositionMarginMode.cross,
  }) {
    final c = context ?? liveContext();
    return mapLiveOrderFunds(
      data,
      address: accountAddress,
      symbol: 'BTCUSDT',
      receivedAt: liveOrderClock,
      assetMode: mode,
      marginMode: marginMode,
      leverage: 10,
      positions: c.positions,
    );
  }

  test('availableBalance keeps USDT precision, distinct from wallet and asset balances', () {
    final data = payload()..['availableBalance'] = '-0.000000000000000001';
    final funds = map(data, mode: FuturesAssetMode.multi);
    expect(funds.account.availableBalance.toString(), '-0.000000000000000001');
    expect(funds.account.walletBalance.toString(), '100.000000000000000001');
    expect(funds.account.assets.first.availableBalance.toString(), '89.000000000000000001');
    expect(funds.assetMode, FuturesAssetMode.multi);
    expect(() => funds.account.assets.clear(), throwsUnsupportedError);
  });
  test('missing available amount stays unknown; zero is explicit', () {
    final data = payload()..remove('availableBalance');
    expect(map(data).account.availableBalance, null);
    data['availableBalance'] = '0';
    expect(map(data).account.availableBalance, Decimal.zero);
  });
  test(
    'malformed account flags, numeric floats, scientific or duplicate asset data are rejected',
    () {
      for (final modify in <void Function(Map<String, dynamic>)>[
        (p) => p['availableBalance'] = 89.0,
        (p) => p['availableBalance'] = '1e8',
        (p) => p['canTrade'] = 'true',
        (p) => (p['assets'] as List).first['availableBalance'] = double.nan,
        (p) => p['assets'] = [(p['assets'] as List).first, (p['assets'] as List).first],
      ]) {
        final data = payload();
        modify(data);
        expect(() => map(data), throwsFormatException);
      }
    },
  );
  test('different position quantity, entry, leverage or margin blocks funding snapshot', () {
    for (final entry in <String, Object>{
      'positionAmt': '0.010000000000000001',
      'entryPrice': '79000.000000000000000001',
      'leverage': '11',
      'isolated': true,
      'positionSide': 'LONG',
    }.entries) {
      final data = payload(position: true);
      (data['positions'] as List).single[entry.key] = entry.value;
      expect(
        () => map(data, context: liveCloseContext()),
        throwsA(isA<AccountReadFailure>()),
        reason: entry.key,
      );
    }
    expect(() => map(payload(), context: liveCloseContext()), throwsA(isA<AccountReadFailure>()));
  });
  test('multi-assets with isolated symbol is inconsistent rather than an automatic switch', () {
    expect(
      () => map(payload(), mode: FuturesAssetMode.multi, marginMode: PositionMarginMode.isolated),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveOrderFundsChanged')),
    );
  });
  test('opening needs signed funds and cannot ignore trading-disabled response', () {
    expect(liveContext(withFunds: false).validate(liveDraft()), 'liveOrderReadFunds');
    expect(liveContext(canTrade: false).validate(liveDraft()), 'liveOrderTradingDisabled');
    expect(liveContext(canTrade: null).validate(liveDraft()), null);
    expect(liveContext(available: null).validate(liveDraft()), null);
    final close = liveCloseIntent();
    final withoutFunds = LiveOrderContext(
      address: accountAddress,
      rules: close.context.rules,
      mode: close.context.mode,
      marginMode: close.context.marginMode,
      leverage: 10,
      markPrice: close.context.markPrice,
      receivedAt: liveOrderClock,
      positions: close.context.positions,
    );
    expect(withoutFunds.validate(close.draft), null);
  });
  test('reference opening margin uses entered limit or mark and read leverage', () {
    final c = liveContext();
    expect(c.estimatedOpeningQuantity(liveDraft()).toString(), '0.001');
    expect(c.estimatedOpeningMargin(liveDraft()).toString(), '8');
    expect(c.estimatedOpeningMargin(liveDraft(price: '81000')).toString(), '8.1');
    expect(c.estimatedOpeningMargin(liveDraft(market: true, price: '1')).toString(), '8');
  });
  test('one-way offsets existing opposite position before estimating new exposure', () {
    for (final short in [false, true]) {
      final c = liveCloseContext(short: short);
      expect(
        c.estimatedOpeningQuantity(liveDraft(buy: !short, quantity: '0.005')).toString(),
        '0.005',
      );
      expect(c.estimatedOpeningQuantity(liveDraft(buy: short, quantity: '0.005')), Decimal.zero);
      expect(c.estimatedOpeningMargin(liveDraft(buy: short, quantity: '0.01')), Decimal.zero);
      expect(
        c.estimatedOpeningQuantity(liveDraft(buy: short, quantity: '0.012')).toString(),
        '0.002',
      );
      expect(c.estimatedOpeningMargin(liveDraft(buy: short, quantity: '0.012')).toString(), '16');
    }
  });
  test('hedge ordinary entries do not net against either existing side', () {
    final c = liveCloseContext(hedge: true);
    for (final buy in [false, true]) {
      expect(
        c.estimatedOpeningQuantity(liveDraft(buy: buy, quantity: '0.002')).toString(),
        '0.002',
      );
      expect(c.estimatedOpeningMargin(liveDraft(buy: buy, quantity: '0.002')).toString(), '16');
    }
  });
  test('valid reduction adds zero opening exposure; invalid reduction remains unknown', () {
    final close = liveCloseIntent();
    expect(close.context.estimatedOpeningMargin(close.draft), Decimal.zero);
    expect(
      close.context.estimatedOpeningQuantity(liveDraft(buy: false, reduceOnly: true)),
      Decimal.zero,
    );
    expect(close.context.estimatedOpeningQuantity(liveDraft(buy: true, reduceOnly: true)), null);
    expect(close.context.estimatedOpeningMargin(liveDraft(quantity: 'NaN')), null);
    expect(close.context.estimatedOpeningMargin(liveDraft(price: '0')), null);
  });
  test('repeating division preserves tiny nonzero margin without binary floating-point', () {
    final base = liveContext();
    final c = LiveOrderContext(
      address: base.address,
      rules: base.rules,
      mode: FuturesPositionMode.oneWay,
      marginMode: base.marginMode,
      leverage: 3,
      markPrice: Decimal.one,
      receivedAt: liveOrderClock,
      positions: base.positions,
      funds: base.funds,
    );
    final tiny = '0.${'0' * 59}1';
    final margin = c.estimatedOpeningMargin(liveDraft(quantity: tiny, market: true))!;
    expect(margin, greaterThan(Decimal.zero));
    expect(margin, lessThan(Decimal.parse(tiny)));
    expect(
      c.estimatedOpeningMargin(liveDraft(quantity: '1', market: true)).toString(),
      '0.333333333333333333333333',
    );
  });
  test('funds from another wallet or an older snapshot cannot authorize an opening', () {
    final base = liveContext();
    for (final wrongWallet in [true, false]) {
      final c = LiveOrderContext(
        address: base.address,
        rules: base.rules,
        mode: base.mode,
        marginMode: base.marginMode,
        leverage: base.leverage,
        markPrice: base.markPrice,
        receivedAt: base.receivedAt,
        positions: base.positions,
        funds: LiveOrderFunds(
          assetMode: FuturesAssetMode.single,
          account: AsterAccount(
            address: wrongWallet ? '0x3333333333333333333333333333333333333333' : base.address,
            receivedAt: wrongWallet
                ? liveOrderClock
                : liveOrderClock.subtract(const Duration(seconds: 1)),
            assets: const [],
            positions: const [],
            canTrade: true,
          ),
        ),
      );
      expect(c.validate(liveDraft()), wrongWallet ? 'authWalletChanged' : 'liveOrderReadFunds');
    }
  });
}

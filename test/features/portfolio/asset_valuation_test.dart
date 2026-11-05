import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

import '../../support/asset_indices.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  AssetIndexState state({
    Map<String, String>? prices,
    int seconds = 0,
    bool failed = false,
    bool active = true,
    DateTime? quoteTime,
    DateTime? receivedAt,
  }) => AssetIndexState(
    checkedAt: now.add(Duration(seconds: seconds)),
    failed: failed,
    active: active,
    snapshot: assetIndexFixture(
      quoteTime ?? now,
      receivedAt: receivedAt,
      prices: prices ?? const {'USDT': '0.99836', 'BTC': '80000'},
    ),
  );
  AssetAmountValue value(String quantity, String asset, AssetIndexState prices) =>
      AssetAmountValue(Decimal.parse(quantity), asset, prices);

  test('stablecoins use actual USD prices and BTC uses its own index', () {
    final usdt = value('100.000000000000000001', 'USDT', state());
    expect(usdt.usd, Decimal.parse('99.83600000000000000099836'));
    expect(usdt.btcFresh, true);
    expect(
      value('0.000000000000000001', 'BTC', state()).btc,
      Decimal.parse('0.000000000000000001'),
    );
    expect(value('-2', 'USDT', state()).usd, Decimal.parse('-1.99672'));
  });
  test('missing prices are unknown, while exact zero is known without quotes', () {
    expect(value('2', 'USDC', state()).usd, null);
    expect(value('2', 'USDC', state()).aboveLowBalanceThreshold, null);
    final zero = value('0', 'UNKNOWN', state(prices: {}));
    expect(zero.usd, Decimal.zero);
    expect(zero.btc, Decimal.zero);
    expect(zero.fresh, true);
    expect(zero.aboveLowBalanceThreshold, false);
  });
  test('threshold uses exact cross multiplication at, above and below 0.0001 BTC', () {
    final prices = state(prices: {'USDT': '1', 'BTC': '80000'});
    expect(value('8', 'USDT', prices).aboveLowBalanceThreshold, false);
    expect(value('8.00000000000000000000000000001', 'USDT', prices).aboveLowBalanceThreshold, true);
    expect(
      value('7.99999999999999999999999999999', 'USDT', prices).aboveLowBalanceThreshold,
      false,
    );
    expect(value('-8', 'USDT', prices).aboveLowBalanceThreshold, false);
    expect(value('0.0001', 'BTC', state()).aboveLowBalanceThreshold, false);
  });
  test('tiny infinite-precision divisions retain positive values', () {
    final amount = value(
      '0.0000000000000000000000000000000000000001',
      'USDT',
      state(prices: {'USDT': '0.99836', 'BTC': '77103.568'}),
    );
    expect(amount.btc, greaterThan(Decimal.zero));
    expect(amount.aboveLowBalanceThreshold, false);
  });
  test('USD and BTC freshness are separate and stale estimates cannot hide assets', () {
    final snapshot = assetIndexFixture(now, prices: {'USDT': '1', 'BTC': '80000'});
    final indices = Map<String, AssetUsdIndex>.of(snapshot.indices);
    indices['BTCUSD'] = AssetUsdIndex(
      symbol: 'BTCUSD',
      usd: Decimal.fromInt(80000),
      time: now.subtract(const Duration(seconds: 90)),
    );
    final prices = AssetIndexState(
      checkedAt: now,
      snapshot: AssetIndexSnapshot(receivedAt: now, indices: indices),
    );
    final amount = value('1', 'USDT', prices);
    expect(amount.fresh, true);
    expect(amount.btcFresh, false);
    expect(amount.aboveLowBalanceThreshold, null);
    for (final prices in [
      state(seconds: 60),
      state(failed: true),
      state(active: false),
      state(quoteTime: now.subtract(const Duration(seconds: 90))),
      state(quoteTime: now.add(const Duration(seconds: 31))),
      state(receivedAt: now.add(const Duration(seconds: 31))),
    ]) {
      final stale = value('1', 'USDT', prices);
      expect(stale.usd, isNotNull);
      expect(stale.fresh, false);
      expect(stale.aboveLowBalanceThreshold, null);
    }
    expect(value('1', 'USDT', state(seconds: 59)).fresh, true);
  });
  test('wallet aggregates exact USD before a single BTC division, counts unknowns', () {
    final prices = state(prices: {'USDT': '1', 'BTC': '3'});
    final wallet = AssetWalletValue([
      value('1', 'USDT', prices),
      value('2', 'USDT', prices),
      value('1', 'UNKNOWN', prices),
      value('0', 'ZERO', prices),
    ], prices);
    expect(wallet.usd, Decimal.fromInt(3));
    expect(wallet.btc, Decimal.one);
    expect(wallet.known, 3);
    expect(wallet.missing, 1);
    expect(wallet.stale, 0);
    expect(AssetWalletValue([value('1', 'UNKNOWN', prices)], prices).known, 0);
  });
  test('known USD is retained when BTC index is unavailable', () {
    final prices = state(prices: {'USDT': '0.99836'});
    final amount = value('1', 'USDT', prices);
    expect(amount.fresh, true);
    expect(amount.btc, null);
    expect(amount.btcFresh, false);
    expect(AssetWalletValue([amount], prices).btc, null);
    expect(AssetWalletValue([amount], prices).btcFresh, false);
  });
}

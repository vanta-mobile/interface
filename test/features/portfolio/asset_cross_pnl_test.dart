import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/portfolio/data/asset_index_repository.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_collateral.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 13);
  const units = AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT');
  AsterPosition position({
    String symbol = 'BTCUSDT',
    String qty = '2',
    String side = 'BOTH',
    String? entry = '100',
    bool? isolated = false,
    AsterContractUnits? contract = units,
  }) => AsterPosition(
    symbol: symbol,
    side: side,
    quantity: Decimal.parse(qty),
    entryPrice: entry == null ? null : Decimal.parse(entry),
    isolated: isolated,
    units: contract,
    unrealizedProfit: Decimal.fromInt(999),
  );
  MarkPrices marks({
    String btc = '110',
    String eth = '190',
    Set<String> fresh = const {'BTCUSDT', 'ETHUSDT'},
    MarkPriceConnection connection = MarkPriceConnection.online,
    Set<String> invalid = const {},
    bool omitBtc = false,
  }) => MarkPrices(
    connection: connection,
    fresh: fresh,
    invalid: invalid,
    quotes: {
      if (!omitBtc)
        'BTCUSDT': MarkPriceQuote(
          symbol: 'BTCUSDT',
          price: Decimal.parse(btc),
          eventTime: now,
          receivedAt: now,
        ),
      'ETHUSDT': MarkPriceQuote(
        symbol: 'ETHUSDT',
        price: Decimal.parse(eth),
        eventTime: now.subtract(const Duration(seconds: 1)),
        receivedAt: now,
      ),
    },
  );
  AssetCollateralValue contribution(AssetCrossPnl pnl, {bool events = false}) =>
      AssetCollateralValue(
        asset: AsterAssetBalance(
          asset: 'USDT',
          walletBalance: Decimal.fromInt(1000),
          crossWalletBalance: Decimal.fromInt(100),
          crossUnrealizedProfit: Decimal.fromInt(2),
          marginAvailable: true,
        ),
        accountReceivedAt: now,
        hasAccountEvents: events,
        liveCrossPnl: pnl,
        prices: AssetIndexState(
          checkedAt: now,
          snapshot: mapAssetIndices([
            {
              'symbol': 'USDTUSD',
              'index': '1',
              'bidRate': '0.9',
              'askRate': '1.1',
              'time': now.millisecondsSinceEpoch,
            },
          ], receivedAt: now),
        ),
      );
  test('linear long and short crossed pnl uses marks, never old per-position aggregate', () {
    final rows = [position(), position(symbol: 'ETHUSDT', qty: '-3', entry: '200', side: 'SHORT')];
    final pnl = AssetCrossPnl(rows, marks());
    expect(pnl.pnl, Decimal.fromInt(50));
    expect(pnl.fresh, true);
    expect(pnl.oldestMark, now.subtract(const Duration(seconds: 1)));
    expect(contribution(pnl).usd, Decimal.fromInt(135));
    expect(contribution(pnl).livePnl, true);
  });
  test('hedge LONG/SHORT signed quantities net their independent entry prices', () {
    final pnl = AssetCrossPnl([
      position(qty: '2', side: 'LONG'),
      position(qty: '-1', side: 'SHORT', entry: '120'),
    ], marks());
    expect(pnl.pnl, Decimal.fromInt(30));
  });
  test('mark changes can turn equity negative and switch conservative rate side', () {
    final pnl = AssetCrossPnl([position(qty: '20', entry: '120')], marks());
    final value = contribution(pnl);
    expect(pnl.pnl, Decimal.fromInt(-200));
    expect(value.equity, Decimal.fromInt(-100));
    expect(value.usd, Decimal.fromInt(-110));
  });
  test('tiny signed quantity and mark differences remain decimal-exact', () {
    final pnl = AssetCrossPnl([
      position(qty: '0.000000000000000001', entry: '100.000000000000000001'),
    ], marks(btc: '100.000000000000000002'));
    expect(pnl.pnl, Decimal.parse('0.000000000000000000000000000000000001'));
  });
  for (final invalid in [
    position(entry: null),
    position(entry: '0'),
    position(isolated: null),
    position(isolated: true),
    position(contract: null),
    position(
      contract: const AsterContractUnits(base: 'BTC', quote: 'USD', margin: 'BTC'),
    ),
  ]) {
    test(
      'incomplete/non-linear position never partially sums and falls back to labelled signed snapshot: $invalid',
      () {
        final pnl = AssetCrossPnl([position(symbol: 'ETHUSDT'), invalid], marks());
        expect(pnl.pnl, null);
        final value = contribution(pnl);
        expect(value.livePnl, false);
        expect(value.usd, Decimal.parse('91.8'));
      },
    );
  }
  test('one missing mark prevents partial live sum and restores full signed aggregate', () {
    final pnl = AssetCrossPnl([position(), position(symbol: 'ETHUSDT')], marks(omitBtc: true));
    expect(pnl.pnl, null);
    expect(contribution(pnl).livePnl, false);
    expect(contribution(pnl).equity, Decimal.fromInt(102));
  });
  test('invalid symbol mark prevents use of its previous quote', () {
    final pnl = AssetCrossPnl([position()], marks(invalid: {'BTCUSDT'}));
    expect(pnl.pnl, null);
  });
  test('stale/disconnected mark preserves last reference with stale status', () {
    for (final data in [marks(fresh: {}), marks(connection: MarkPriceConnection.offline)]) {
      final pnl = AssetCrossPnl([position()], data);
      expect(pnl.pnl, Decimal.fromInt(20));
      final value = contribution(pnl);
      expect(value.livePnl, true);
      expect(value.fresh, false);
    }
  });
  test('account event still blocks calculation even with fresh complete marks', () {
    final value = contribution(AssetCrossPnl([position()], marks()), events: true);
    expect(value.usd, null);
    expect(value.issue, AssetCollateralIssue.events);
  });
  test(
    'asset grouping excludes isolated, zero and different margin assets but retains unknown units',
    () {
      final unknown = position(contract: null), crossed = position();
      final rows = collateralPositions([
        crossed,
        position(isolated: true),
        position(qty: '0'),
        unknown,
        position(
          contract: const AsterContractUnits(base: 'BTC', quote: 'USDC', margin: 'USDC'),
        ),
      ], 'USDT');
      expect(rows, [crossed, unknown]);
      expect(() => rows.clear(), throwsUnsupportedError);
    },
  );
  test('no relevant positions uses original signed cross-PnL rather than invented zero', () {
    final pnl = AssetCrossPnl([], marks());
    expect(pnl.pnl, null);
    expect(contribution(pnl).equity, Decimal.fromInt(102));
    expect(contribution(pnl).livePnl, false);
  });
}

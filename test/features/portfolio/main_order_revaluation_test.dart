import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_revaluation.dart';

void main() {
  late Map<String, dynamic> payload;
  late List<dynamic> orders;
  late Map<String, String> markValues, lastValues;
  late DateTime now;
  late bool hedge, isolated, multi;
  setUp(() {
    payload = capacityAccountPayload();
    (payload['assets'] as List).single['crossWalletBalance'] = '100';
    orders = [];
    markValues = {'BTCUSDT': '100'};
    lastValues = {'BTCUSDT': '100'};
    now = liveOrderClock;
    hedge = isolated = multi = false;
  });
  MainOrderCapacitySnapshot anchor() {
    // Deliberately unrelated available/initial/PnL snapshot values: revaluation
    // must rebuild the complete budget from wallets, positions and pending orders.
    final base = assembledCapacity(context: capacityContext());
    final context = capacityContext(
      payload: payload,
      hedge: hedge,
      isolated: isolated,
      assetMode: multi ? FuturesAssetMode.multi : FuturesAssetMode.single,
    );
    return withRevaluationFacts(
      MainOrderCapacitySnapshot(
        context: context,
        account: base.account,
        assetMode: context.funds!.assetMode,
        availableMargin: base.availableMargin,
        exposure: base.exposure,
        notionalCap: base.notionalCap,
        contractCap: base.contractCap,
        receivedAt: base.receivedAt,
      ),
      payload: payload,
      orders: orders,
    );
  }

  Map<String, OrderReferencePrices> references() => {
    for (final e in lastValues.entries)
      e.key: revaluationReference(symbol: e.key, last: e.value, time: now),
  };
  MainOrderRevaluation value({
    MainOrderCapacitySnapshot? snapshot,
    MarkPrices? marks,
    Map<String, OrderReferencePrices>? prices,
  }) => revalueMainOrderCapacity(
    snapshot: snapshot ?? anchor(),
    marks: marks ?? revaluationMarks(markValues, time: now),
    references: prices ?? references(),
    indices: multi ? capacityIndices(time: now, usdtBid: '1', usdtAsk: '1') : null,
    now: now,
  );
  Matcher fails(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'failure', key));
  void position({
    String symbol = 'BTCUSDT',
    String side = 'BOTH',
    String quantity = '1',
    bool isolated = false,
    bool replace = true,
  }) {
    final p = capacityPosition(symbol: symbol, side: side, quantity: quantity, isolated: isolated);
    if (replace) {
      payload['positions'] = [p];
    } else {
      (payload['positions'] as List).add(p);
    }
  }

  void order({
    String symbol = 'BTCUSDT',
    String side = 'SELL',
    String positionSide = 'BOTH',
    String quantity = '3',
    String type = 'LIMIT',
    bool reduceOnly = false,
  }) {
    orders.add({
      ...capacityOrder(
        side: side,
        positionSide: positionSide,
        quantity: quantity,
        executed: '0',
        type: type,
        reduceOnly: reduceOnly,
      ),
      'symbol': symbol,
      'orderId': orders.length + 10,
    });
  }

  for (final mark in ['100', '120']) {
    test('PRD cross one-long example at $mark recomputes wallet, PnL and margin', () {
      position();
      markValues['BTCUSDT'] = mark;
      lastValues['BTCUSDT'] = mark;
      final v = value();
      expect(v.availableMargin, d(mark == '100' ? '90' : '108').toRational());
      expect(v.exposure.signedNotional, d(mark));
      expect(v.context.markPrice, d(mark));
      expect(v.assets['USDT']!.crossPnl, d(mark == '100' ? '0' : '20'));
    });
  }
  for (final long in [true, false]) {
    test('takes smaller signed Mark/Last PnL separately for ${long ? 'long' : 'short'}', () {
      position(quantity: long ? '1' : '-1');
      markValues['BTCUSDT'] = '120';
      lastValues['BTCUSDT'] = '110';
      expect(value().availableMargin, d(long ? '98' : '68').toRational());
    });
  }
  test('unselected cross symbol changes the shared budget', () {
    position(symbol: 'ETHUSDT', quantity: '2', replace: false);
    markValues['ETHUSDT'] = '80';
    lastValues['ETHUSDT'] = '90';
    final v = value();
    expect(v.availableMargin, d('44').toRational());
    expect(v.assets['USDT']!.crossInitialMargin, d('16').toRational());
    expect(v.assets['USDT']!.crossPnl, d('-40'));
    expect(v.exposure.currentNotional, d('0'));
  });
  test('opposite pending exposure is recomputed after Mark changes', () {
    position();
    order();
    markValues['BTCUSDT'] = lastValues['BTCUSDT'] = '120';
    final v = value();
    expect(v.exposure.currentNotional, d('180'));
    expect(v.availableMargin, d('102').toRational());
  });
  test('isolated position PnL stays out of cross budget; pending extra is recomputed', () {
    position(symbol: 'ETHUSDT', isolated: true, replace: false);
    order(symbol: 'ETHUSDT');
    markValues['ETHUSDT'] = '120';
    // No ETH Last is needed: isolated PnL does not enter this cross budget.
    final v = value();
    expect(v.availableMargin, d('94').toRational());
    expect(v.assets['USDT']!.isolatedOrderMargin, d('6').toRational());
    expect(v.assets['USDT']!.crossPnl, d('0'));
  });
  test('isolated budget uses min(available, wallet less updated cross maintenance)', () {
    isolated = true;
    (payload['positions'] as List).single['isolated'] = true;
    position(symbol: 'ETHUSDT', replace: false);
    markValues['ETHUSDT'] = lastValues['ETHUSDT'] = '120';
    final v = value();
    expect(v.availableMargin, d('99.4').toRational());
    expect(v.assets['USDT']!.crossMaintenance, d('0.6'));
  });
  test('maintenance selects next tier exactly at its floor and subtracts cumulative', () {
    isolated = true;
    (payload['positions'] as List).single['isolated'] = true;
    (payload['assets'] as List).single['crossWalletBalance'] = '1000';
    position(symbol: 'ETHUSDT', quantity: '10', replace: false);
    markValues['ETHUSDT'] = lastValues['ETHUSDT'] = '120';
    expect(value().assets['USDT']!.crossMaintenance, d('7'));
    markValues['ETHUSDT'] = lastValues['ETHUSDT'] = '100';
    expect(value().assets['USDT']!.crossMaintenance, d('5'));
  });
  test('hedge includes both legs, opening orders, and independently smaller PnLs', () {
    hedge = true;
    position(side: 'LONG');
    position(side: 'SHORT', quantity: '-2', replace: false);
    order(side: 'BUY', positionSide: 'LONG', quantity: '0.5');
    order(side: 'SELL', positionSide: 'SHORT', quantity: '0.7');
    markValues['BTCUSDT'] = '110';
    lastValues['BTCUSDT'] = '120';
    final v = value();
    expect(v.exposure.currentNotional, d('450'));
    expect(v.availableMargin, d('25').toRational());
    expect(v.assets['USDT']!.crossPnl, d('-30'));
  });
  test('repeating leverage division remains rational through the budget', () {
    position();
    (payload['positions'] as List).single['leverage'] = '3';
    expect(value().availableMargin, d('200') / d('3'));
  });
  test('negative equity stays negative instead of pretending unknown is zero', () {
    position(quantity: '10');
    markValues['BTCUSDT'] = lastValues['BTCUSDT'] = '1';
    expect(value().availableMargin, d('-891').toRational());
  });
  for (final closing in [true, false]) {
    test('${closing ? 'closing' : 'opening'} conditional on another related symbol', () {
      position(symbol: 'ETHUSDT', replace: false);
      markValues['ETHUSDT'] = lastValues['ETHUSDT'] = '100';
      order(symbol: 'ETHUSDT', type: 'STOP_MARKET', reduceOnly: closing);
      if (closing) {
        expect(value().availableMargin, d('90').toRational());
      } else {
        expect(() => value(), fails('liveCapacityPendingUnknown'));
      }
    });
  }
  test('flat configuration with pending order contributes without needing a mark', () {
    position(symbol: 'ETHUSDT', quantity: '0', replace: false);
    order(symbol: 'ETHUSDT', side: 'BUY', quantity: '2');
    expect(value().availableMargin, d('80').toRational());
  });
  test('missing configuration for an account-wide order blocks revaluation', () {
    order(symbol: 'ETHUSDT');
    expect(() => value(), fails('liveCapacityChanged'));
  });
  test('incomplete hedge configuration is not treated as an empty leg', () {
    hedge = true;
    position(side: 'LONG');
    expect(() => value(), fails('accountDataInvalid'));
  });
  test('missing tier and notional outside all tiers do not invent maintenance', () {
    position();
    final base = anchor();
    final missing = withRevaluationFacts(base, tiers: {});
    expect(() => value(snapshot: missing), fails('liveCapacityChanged'));
    markValues['BTCUSDT'] = '100000';
    expect(() => value(), fails('liveCapacityChanged'));
  });
  for (final negative in [false, true]) {
    test(
      'multi-asset ${negative ? 'negative' : 'positive'} collateral uses smaller bid/ask product',
      () {
        multi = true;
        position(quantity: '2');
        (payload['assets'] as List).add({
          ...capacityAsset(asset: 'BNB'),
          'crossWalletBalance': negative ? '-2' : '2',
        });
        // support indices: BNB bid=300, ask=310. USDT position margin=20.
        expect(value().availableMargin, d(negative ? '-540' : '680').toRational());
      },
    );
  }
  test('non-margin collateral is excluded, including its large signed snapshot initialMargin', () {
    multi = true;
    (payload['assets'] as List).add({...capacityAsset(asset: 'BNB'), 'marginAvailable': false});
    expect(value().availableMargin, d('100').toRational());
  });
  test('multi-asset active isolated position is unsupported', () {
    multi = true;
    position(symbol: 'ETHUSDT', isolated: true, replace: false);
    expect(() => value(), fails('liveCapacityChanged'));
  });
  for (final channel in ['mark', 'trade', 'book']) {
    for (final age in [const Duration(seconds: 10), const Duration(milliseconds: -1)]) {
      test('$channel with ${age.inMilliseconds}ms receipt age is unavailable', () {
        final time = now.subtract(age);
        final prices = references();
        if (channel == 'mark') {
          expect(
            () => value(marks: revaluationMarks(markValues, time: time)),
            fails('liveCapacityPriceUnavailable'),
          );
        } else {
          final old = revaluationReference(time: time), fresh = prices['BTCUSDT']!;
          prices['BTCUSDT'] = OrderReferencePrices(
            symbol: 'BTCUSDT',
            checkedAt: now,
            connection: OrderPriceConnection.online,
            tradeFresh: true,
            bookFresh: true,
            book: channel == 'book' ? old.book : fresh.book,
            trade: channel == 'trade' ? old.trade : fresh.trade,
          );
          expect(() => value(prices: prices), fails('liveCapacityPriceUnavailable'));
        }
      });
    }
  }
  for (final channel in ['mark', 'trade', 'book']) {
    test('$channel disconnected or invalidated never uses the retained value', () {
      final prices = references(), marks = revaluationMarks(markValues);
      if (channel == 'mark') {
        expect(
          () => value(
            marks: MarkPrices(
              quotes: marks.quotes,
              fresh: marks.fresh,
              connection: MarkPriceConnection.offline,
            ),
          ),
          fails('liveCapacityPriceUnavailable'),
        );
      } else {
        final previous = prices['BTCUSDT']!;
        prices['BTCUSDT'] = OrderReferencePrices(
          symbol: 'BTCUSDT',
          checkedAt: now,
          connection: OrderPriceConnection.online,
          book: previous.book,
          trade: previous.trade,
          bookFresh: channel != 'book',
          tradeFresh: channel != 'trade',
        );
        expect(() => value(prices: prices), fails('liveCapacityPriceUnavailable'));
      }
    });
  }
  for (final missing in ['mark', 'last']) {
    test('missing $missing on another nonzero cross symbol invalidates the entire budget', () {
      position(symbol: 'ETHUSDT', replace: false);
      if (missing == 'mark') {
        lastValues['ETHUSDT'] = '100';
      } else {
        markValues['ETHUSDT'] = '100';
      }
      expect(() => value(), fails('liveCapacityPriceUnavailable'));
    });
  }
  for (final (channel, reason) in [
    ('mark', 'livePriceMarkStale'),
    ('trade', 'livePriceLastStale'),
    ('book', 'livePriceBookStale'),
  ]) {
    test('$channel retains a concrete localized cause', () {
      final prices = references();
      final old = revaluationReference(time: now.subtract(const Duration(seconds: 10)));
      final fresh = prices['BTCUSDT']!;
      if (channel != 'mark') {
        prices['BTCUSDT'] = OrderReferencePrices(
          symbol: 'BTCUSDT',
          checkedAt: now,
          connection: OrderPriceConnection.online,
          tradeFresh: true,
          bookFresh: true,
          book: channel == 'book' ? old.book : fresh.book,
          trade: channel == 'trade' ? old.trade : fresh.trade,
        );
      }
      expect(
        () => value(
          prices: prices,
          marks: channel == 'mark'
              ? revaluationMarks(markValues, time: now.subtract(const Duration(seconds: 10)))
              : null,
        ),
        throwsA(isA<AccountReadFailure>().having((e) => e.reasonKey, 'reason', reason)),
      );
    });
  }
  test('fresh public prices do not extend the signed account 30s lease', () {
    now = now.add(const Duration(seconds: 30));
    expect(() => value(), fails('liveOrderContextExpired'));
    now = liveOrderClock.subtract(const Duration(milliseconds: 1));
    expect(() => value(), fails('liveOrderContextExpired'));
  });
  test('account anchor is immutable, independent estimates never mutate signed facts', () {
    position();
    final base = anchor();
    markValues['BTCUSDT'] = lastValues['BTCUSDT'] = '120';
    final v = value(snapshot: base);
    expect(v.anchor, same(base));
    expect(base.context.markPrice, d('100'));
    expect(base.account.positions.single.notional, d('100'));
    expect(v.context.receivedAt, base.context.receivedAt);
    expect(v.context.bid, d('99'));
    expect(v.context.ask, d('101'));
    expect(v.context.lastPrice, d('120'));
    expect(() => v.assets.clear(), throwsUnsupportedError);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/spot_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';

import '../../support/aster_account.dart';
import '../../support/spot_history.dart';

void main() {
  SpotHistoryPage map(SpotHistoryKind kind, List<Object?> rows, {String scope = ''}) =>
      mapSpotHistory(
        rows,
        address: accountAddress,
        query: SpotHistoryQuery(kind: kind, window: historyWindow, scope: scope),
        receivedAt: historyNow,
        units: mapSpotSymbolUnits(spotSymbols()),
      );

  test(
    'order history retains every status, units and Decimal precision without inventing fills',
    () {
      final result = map(SpotHistoryKind.orders, [
        spotOrderRow(),
        spotOrderRow(id: 2, status: 'PARTIALLY_FILLED', executed: '1'),
        spotOrderRow(id: 3, status: 'CANCELED'),
        spotOrderRow(id: 4, status: 'FILLED', executed: '5'),
        spotOrderRow(id: 5, status: 'EXPIRED'),
        spotOrderRow(id: 6, status: 'REJECTED'),
        spotOrderRow(id: 7, status: 'FUTURE_STATUS'),
      ]);
      expect(result.records.length, 7);
      expect((result.records.first as SpotOrderRecord).price.toString(), '1.100000000000000001');
      expect(
        result.records.whereType<SpotOrderRecord>().map((r) => r.status),
        containsAll([
          'NEW',
          'PARTIALLY_FILLED',
          'CANCELED',
          'FILLED',
          'EXPIRED',
          'REJECTED',
          'FUTURE_STATUS',
        ]),
      );
      expect((result.records.first as SpotOrderRecord).units!.base, 'BNB');
      expect(() => result.records.clear(), throwsUnsupportedError);
      final unfilled = result.records.whereType<SpotOrderRecord>().firstWhere(
        (r) => r.status == 'NEW',
      );
      expect(unfilled.executed.toString(), '0');
      expect(unfilled.averagePrice.toString(), '0');
    },
  );

  test('fills use symbol and trade ID, preserve fee asset and rebate sign', () {
    final result = map(SpotHistoryKind.trades, [
      spotTradeRow(),
      spotTradeRow(id: 1003),
      spotTradeRow(symbol: 'BTCUSDT'),
    ]);
    expect(result.records.length, 3);
    final trade = result.records.first as SpotTradeRecord;
    expect(trade.quantity.toString(), '0.000000000000000001');
    expect(trade.quoteQuantity.toString(), '0.0000000000000000011');
    expect(trade.commission.toString(), '-0.000000000000000001');
    expect(trade.commissionAsset, 'BNB');
    expect(trade.orderId, '349661');
  });

  test('ledger retains negative amounts, long IDs, optional trade references and future types', () {
    final result = map(SpotHistoryKind.transactions, [
      spotTransactionRow(),
      spotTransactionRow(type: 'TRADE_TARGET', asset: 'USDT'),
      spotTransactionRow(type: 'PREDICTION_NEW'),
    ]);
    expect(result.records.length, 3);
    final row = result.records.first as SpotTransactionRecord;
    expect(row.transactionId, '1759115482304540227');
    expect(row.delta.toString(), '-500.000000000000000001');
    expect(row.tradeId, null);
    expect(row.symbol, isEmpty);
  });

  test('duplicate order versions retain newest update; raw row count still detects cap', () {
    final result = map(SpotHistoryKind.orders, [
      spotOrderRow(status: 'CANCELED', updated: historyTime + 10),
      spotOrderRow(),
      spotOrderRow(symbol: 'BTCUSDT'),
    ]);
    expect(result.rawCount, 3);
    expect(result.records.length, 2);
    expect(
      result.records.whereType<SpotOrderRecord>().firstWhere((r) => r.symbol == 'BNBUSDT').status,
      'CANCELED',
    );
    final capped = map(SpotHistoryKind.orders, List.generate(1000, (_) => spotOrderRow()));
    expect(capped.rawCount, 1000);
    expect(capped.records.length, 1);
  });

  test('bad or missing money is rejected for every history kind without silent zero', () {
    for (final value in <Object?>[null, 1.1, '1e3', 'NaN', 'Infinity', '-1', 'secret\ntrace']) {
      expect(
        () => map(SpotHistoryKind.orders, [spotOrderRow()..['price'] = value]),
        throwsFormatException,
      );
      expect(
        () => map(SpotHistoryKind.trades, [spotTradeRow()..['qty'] = value]),
        throwsFormatException,
      );
    }
    for (final value in <Object?>[null, 1.1, '1e3', '--1', 'secret']) {
      expect(
        () => map(SpotHistoryKind.transactions, [spotTransactionRow()..['balanceDelta'] = value]),
        throwsFormatException,
      );
    }
    expect(() => map(SpotHistoryKind.orders, [spotOrderRow(executed: '6')]), throwsFormatException);
    expect(
      () => map(SpotHistoryKind.trades, [spotTradeRow()..['buyer'] = false]),
      throwsFormatException,
    );
  });

  test('wrong scopes, out-of-window times, bad identifiers and invalid duplicates fail safely', () {
    expect(
      () => map(SpotHistoryKind.orders, [spotOrderRow()], scope: 'BTCUSDT'),
      throwsFormatException,
    );
    expect(
      () => map(SpotHistoryKind.transactions, [spotTransactionRow()], scope: 'USDT'),
      throwsFormatException,
    );
    for (final time in [historyWindow.start - 1, historyWindow.end + 1]) {
      expect(() => map(SpotHistoryKind.trades, [spotTradeRow(time: time)]), throwsFormatException);
    }
    expect(
      () => map(SpotHistoryKind.orders, [spotOrderRow(), spotOrderRow(time: historyTime + 1)]),
      throwsFormatException,
    );
    expect(
      () => map(SpotHistoryKind.transactions, [spotTransactionRow()..['asset'] = 'BTC\nraw']),
      throwsFormatException,
    );
    expect(
      () => map(SpotHistoryKind.transactions, [spotTransactionRow()..['type'] = 'bad payload']),
      throwsFormatException,
    );
    expect(() => map(SpotHistoryKind.orders, [spotOrderRow(id: 1.0)]), throwsFormatException);
    expect(
      () => map(SpotHistoryKind.orders, List.generate(1001, (_) => spotOrderRow())),
      throwsFormatException,
    );
  });

  test('conflicting immutable event duplicates fail instead of hiding a changed amount', () {
    expect(
      () => map(SpotHistoryKind.trades, [spotTradeRow(), spotTradeRow()..['commission'] = '1']),
      throwsFormatException,
    );
    expect(
      () => map(SpotHistoryKind.transactions, [
        spotTransactionRow(),
        spotTransactionRow()..['balanceDelta'] = '-1',
      ]),
      throwsFormatException,
    );
    expect(map(SpotHistoryKind.trades, [spotTradeRow(), spotTradeRow()]).records.length, 1);
  });

  test('metadata includes inactive Spot pairs and never derives units from the symbol', () {
    final units = mapSpotSymbolUnits(spotSymbols());
    expect(units['BNBUSDT']!.base, 'BNB');
    final row =
        map(SpotHistoryKind.orders, [spotOrderRow(symbol: 'UNKNOWN')]).records.single
            as SpotOrderRecord;
    expect(row.units, null);
    final unicode = map(SpotHistoryKind.transactions, [spotTransactionRow(asset: '币安人生')]);
    expect((unicode.records.single as SpotTransactionRecord).asset, '币安人生');
  });

  test('inclusive splits never skip or double-cover a millisecond', () {
    for (final size in [1, 2, 3, 100, 999999]) {
      final window = HistoryWindow(42, 42 + size);
      final split = window.split();
      expect(split.first.start, window.start);
      expect(split.last.end, window.end);
      expect(split.first.end + 1, split.last.start);
      expect(split.every((w) => w.end - w.start < window.end - window.start), true);
    }
    expect(const HistoryWindow(42, 42).split(), isEmpty);
    expect(HistoryWindow.recent(historyNow, const Duration(days: 7)).valid, true);
    expect(HistoryWindow.recent(historyNow, const Duration(days: 8)).fitsRequest, false);
  });
}

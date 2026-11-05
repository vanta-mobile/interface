import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/futures_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/domain/futures_history_merge.dart';

import '../../support/aster_account.dart';
import '../../support/futures_history.dart';

void main() {
  FuturesHistoryPage map(
    List<Object?> rows, {
    FuturesHistoryKind kind = FuturesHistoryKind.orders,
    String symbol = '',
    String incomeType = '',
    bool units = true,
  }) => mapFuturesHistory(
    rows,
    address: accountAddress,
    query: futuresQuery(kind, symbol: symbol, incomeType: incomeType),
    receivedAt: futuresHistoryNow,
    units: units ? futuresHistoryUnits : const {},
  );
  test('canceled partial fill retains actual Decimal quantities, notional and separate times', () {
    final r = map([futuresOrderRow()]).records.single as FuturesOrderRecord;
    expect(r.quantity, Decimal.parse('0.002'));
    expect(r.executed, Decimal.parse('0.001'));
    expect(r.quoteFilled, Decimal.parse('80.000000000000000001'));
    expect(r.status, 'CANCELED');
    expect(r.clientOrderId, 'vanta-history-123');
    expect(r.units!.base, 'BTC');
    expect(r.units!.margin, 'USDT');
    expect(r.time.isUtc, true);
  });
  test('missing optional totals, mean, flags and original type remain unknown', () {
    final row = futuresOrderRow()
      ..remove('cumQuote')
      ..remove('avgPrice')
      ..remove('origType')
      ..remove('closePosition')
      ..remove('reduceOnly');
    final r = map([row], units: false).records.single as FuturesOrderRecord;
    expect(r.quoteFilled, null);
    expect(r.averagePrice, null);
    expect(r.originalType, null);
    expect(r.closePosition, null);
    expect(r.reduceOnly, null);
    expect(r.units, null);
  });
  test('entire close zero planned quantity can have actual filled quantity', () {
    final r =
        map([
              {
                ...futuresOrderRow(),
                'origQty': '0',
                'executedQty': '0.005',
                'closePosition': true,
                'status': 'FILLED',
              },
            ]).records.single
            as FuturesOrderRecord;
    expect(r.quantity, Decimal.zero);
    expect(r.executed, Decimal.parse('0.005'));
  });
  for (final status in [
    'NEW',
    'PARTIALLY_FILLED',
    'FILLED',
    'CANCELED',
    'EXPIRED',
    'EXPIRED_IN_MATCH',
    'REJECTED',
    'PENDING_CANCEL',
    'FUTURE_STATUS',
  ]) {
    test('known and unknown safe status retained $status', () {
      final executed = status == 'NEW'
          ? '0'
          : status == 'FILLED'
          ? '0.002'
          : '0.001';
      final r =
          map([
                {
                  ...futuresOrderRow(),
                  'status': status,
                  'executedQty': executed,
                  'cumQuote': executed == '0' ? '0' : '80',
                  'avgPrice': executed == '0' ? '0' : '80000',
                },
              ]).records.single
              as FuturesOrderRecord;
      expect(r.status, status);
    });
  }
  for (final change in <String, Object?>{
    'symbol': 'BTC USDT',
    'orderId': 1.25,
    'clientOrderId': 'token\nsecret',
    'time': -1,
    'updateTime': 0,
    'positionSide': 'INVALID',
    'side': 'LONG',
    'origQty': '0',
    'executedQty': '0.003',
    'price': 'NaN',
    'avgPrice': 1.5,
    'cumQuote': '-1',
    'stopPrice': '1e3',
    'reduceOnly': 'false',
    'closePosition': 1,
    'priceProtect': 'true',
    'timeInForce': 'GTC&user=x',
    'origType': 'a' * 61,
  }.entries) {
    test(
      'malformed order field fails safely ${change.key}',
      () => expect(
        () => map([
          {...futuresOrderRow(), change.key: change.value},
        ]),
        throwsFormatException,
      ),
    );
  }
  for (final row in [
    {'status': 'NEW'},
    {'status': 'FILLED'},
    {'status': 'PARTIALLY_FILLED', 'executedQty': '0'},
    {'executedQty': '0', 'cumQuote': '1'},
    {'executedQty': '0', 'cumQuote': '0', 'avgPrice': '1'},
    {'status': 'PARTIALLY_FILLED', 'executedQty': '0.002'},
  ]) {
    test(
      'contradictory order status/amount rejected $row',
      () => expect(
        () => map([
          {...futuresOrderRow(), ...row},
        ]),
        throwsFormatException,
      ),
    );
  }
  test('trades are individual events, share order id, keep signed fee/reported PnL', () {
    final records = map(
      [futuresTradeRow(), futuresTradeRow(id: '98766')],
      kind: FuturesHistoryKind.trades,
      symbol: 'BTCUSDT',
    ).records.cast<FuturesTradeRecord>();
    expect(records, hasLength(2));
    expect(records.first.orderId, records.last.orderId);
    expect(records.first.commission, Decimal.parse('-0.008000000000000001'));
    expect(records.first.realizedPnl, Decimal.parse('-1.250000000000000001'));
    expect(records.first.commissionAsset, 'BNB');
    expect(records.first.units!.margin, 'USDT');
  });
  for (final change in <String, Object?>{
    'id': true,
    'orderId': '01',
    'buyer': true,
    'maker': 'true',
    'positionSide': 'CLOSE',
    'qty': '0',
    'price': '0',
    'commission': '-NaN',
    'realizedPnl': 0.1,
    'quoteQty': '-1',
    'commissionAsset': 'BNB\nsecret',
  }.entries) {
    test(
      'invalid trade field rejected ${change.key}',
      () => expect(
        () => map(
          [
            {...futuresTradeRow(), change.key: change.value},
          ],
          kind: FuturesHistoryKind.trades,
          symbol: 'BTCUSDT',
        ),
        throwsFormatException,
      ),
    );
  }
  test('income dedupe scopes transaction ID to type, signed tiny amount preserved', () {
    final records = map([
      futuresIncomeRow(),
      {...futuresIncomeRow(), 'incomeType': 'COMMISSION'},
    ], kind: FuturesHistoryKind.income).records.cast<FuturesIncomeRecord>();
    expect(records, hasLength(2));
    expect(records.first.income, Decimal.parse('-0.000000000000000001'));
    expect(records.first.transactionId, '45678');
    expect(records.first.tradeId, null);
  });
  test('income without symbol/trade linkage and safe future type retained', () {
    final r =
        map([
              {
                ...futuresIncomeRow(),
                'symbol': '',
                'incomeType': 'NEW_REWARD',
                'income': '2',
                'tradeId': '9007199254740993',
              },
            ], kind: FuturesHistoryKind.income).records.single
            as FuturesIncomeRecord;
    expect(r.symbol, '');
    expect(r.tradeId, '9007199254740993');
    expect(r.type, 'NEW_REWARD');
  });
  for (final change in <String, Object?>{
    'tranId': null,
    'incomeType': '<secret>',
    'income': '1e2',
    'asset': '',
    'time': 1.5,
    'tradeId': '1&x=2',
    'symbol': null,
  }.entries) {
    test(
      'invalid income field rejected ${change.key}',
      () => expect(
        () => map([
          {...futuresIncomeRow(), change.key: change.value},
        ], kind: FuturesHistoryKind.income),
        throwsFormatException,
      ),
    );
  }
  test('filter/window boundaries inclusive; no out-of-scope records accepted', () {
    final time = futuresHistoryWindow.start;
    expect(map([futuresOrderRow(time: time)]).records, hasLength(1));
    expect(() => map([futuresOrderRow(time: time - 1)]), throwsFormatException);
    expect(() => map([futuresOrderRow()], symbol: 'ETHUSDT'), throwsFormatException);
    expect(
      () => map([futuresIncomeRow()], kind: FuturesHistoryKind.income, incomeType: 'COMMISSION'),
      throwsFormatException,
    );
  });
  test('invalid queries and non-list / overfull responses rejected', () {
    for (final payload in <Object?>[null, {}, 'raw', List.filled(1001, futuresOrderRow())]) {
      expect(
        () => mapFuturesHistory(
          payload,
          address: accountAddress,
          query: futuresQuery(FuturesHistoryKind.orders),
          receivedAt: futuresHistoryNow,
        ),
        throwsFormatException,
      );
    }
    expect(futuresQuery(FuturesHistoryKind.trades).valid, false);
    expect(
      futuresQuery(
        FuturesHistoryKind.orders,
        window: const HistoryWindow(0, 7 * 24 * 60 * 60 * 1000),
      ).window.fitsRequest,
      false,
    );
    expect(futuresQuery(FuturesHistoryKind.orders, incomeType: 'COMMISSION').valid, false);
  });
  test('identical repeats dedupe but raw count remains saturated', () {
    final page = map(List.filled(1000, futuresOrderRow()));
    expect(page.rawCount, 1000);
    expect(page.records, hasLength(1));
    expect(() => page.records.clear(), throwsUnsupportedError);
  });
  for (final kind in FuturesHistoryKind.values) {
    test('same-key financial conflicts cannot hide a different record $kind', () {
      final row = switch (kind) {
        FuturesHistoryKind.orders => futuresOrderRow(),
        FuturesHistoryKind.trades => futuresTradeRow(),
        FuturesHistoryKind.income => futuresIncomeRow(),
      };
      final change = switch (kind) {
        FuturesHistoryKind.orders => {'price': '80001'},
        FuturesHistoryKind.trades => {'realizedPnl': '-2'},
        FuturesHistoryKind.income => {'asset': 'BNB'},
      };
      expect(
        () => map(
          [
            row,
            {...row, ...change},
          ],
          kind: kind,
          symbol: kind == FuturesHistoryKind.trades ? 'BTCUSDT' : '',
        ),
        throwsFormatException,
      );
    });
  }
  test(
    'order newer version wins regardless of arrival; terminal/quantity regressions rejected',
    () {
      final t = futuresHistoryNow.millisecondsSinceEpoch;
      final old = map([
        {...futuresOrderRow(), 'status': 'PARTIALLY_FILLED', 'updateTime': t - 1, 'time': t - 2},
      ]).records.single;
      final next = map([
        {...futuresOrderRow(), 'time': t - 2},
      ]).records.single;
      expect(mergeFuturesHistory([next], [old]).single, same(next));
      expect(mergeFuturesHistory([old], [next]).single, same(next));
      for (final change in [
        {'status': 'NEW', 'executedQty': '0', 'cumQuote': '0', 'avgPrice': '0'},
        {'status': 'CANCELED', 'executedQty': '0.0001'},
      ]) {
        final regressed = map([
          {...futuresOrderRow(), 'time': t - 2, 'updateTime': t + 1, ...change},
        ]).records.single;
        expect(() => mergeFuturesHistory([next], [regressed]), throwsFormatException);
      }
    },
  );
  test('order update may be outside creation filter and conditional type can transform', () {
    final r =
        map([
              {
                ...futuresOrderRow(),
                'time': futuresHistoryWindow.start,
                'updateTime': futuresHistoryWindow.end + 1,
                'origType': 'STOP',
                'type': 'LIMIT',
              },
            ]).records.single
            as FuturesOrderRecord;
    expect(r.originalType, 'STOP');
    expect(r.type, 'LIMIT');
  });
  test('original order type is immutable across versions; missing type may be enriched', () {
    final t = futuresHistoryNow.millisecondsSinceEpoch;
    final old = map([
      {...futuresOrderRow(), 'time': t - 2, 'updateTime': t - 1},
    ]).records.single;
    final changed = map([
      {...futuresOrderRow(), 'time': t - 2, 'origType': 'STOP'},
    ]).records.single;
    expect(() => mergeFuturesHistory([old], [changed]), throwsFormatException);
    expect(() => mergeFuturesHistory([changed], [old]), throwsFormatException);
    final missing = map([
      {...futuresOrderRow(), 'time': t - 2, 'updateTime': t - 1, 'origType': null},
    ]).records.single;
    expect(mergeFuturesHistory([missing], [changed]).single, same(changed));
  });
}

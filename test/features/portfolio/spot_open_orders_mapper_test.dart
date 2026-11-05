import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/spot_notification_mapper.dart';
import 'package:vanta/features/portfolio/data/spot_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/spot_open_orders.dart';

import '../../support/aster_account.dart';
import '../../support/spot_open_orders.dart';
import '../../support/notifications.dart';

void main() {
  final time = DateTime.fromMillisecondsSinceEpoch(spotOrderTime, isUtc: true);
  SpotOpenOrders map(Object? rows) =>
      mapSpotOpenOrders(rows, address: accountAddress, receivedAt: time, units: spotOrderUnits);
  test('exact Spot quantities, IDs and units have no Perp synthesis', () {
    final o = map([spotOpenOrderPayload()]).orders.single;
    expect(o.orderId, '9007199254740993');
    expect(o.quantity.toString(), '0.100000000000000001');
    expect(o.price.toString(), '80000.000000000000000001');
    expect(o.remaining, o.quantity);
    expect(o.quoteFilled, Decimal.zero);
    expect(o.units!.base, 'BTC');
    expect(o.units!.quote, 'USDT');
    expect(o.time, time);
    expect(o.updatedAt, time);
    expect(o.clientOrderId, 'original-9007199254740993');
  });
  test('snapshot lists immutable; empty list has explicit complete baseline', () {
    final s = map([]);
    expect(s.orders, isEmpty);
    expect(() => s.orders.clear(), throwsUnsupportedError);
    expect(() => s.units.clear(), throwsUnsupportedError);
  });
  test('identical duplicates collapse, same numeric ID across symbols is separate', () {
    final s = map([
      spotOpenOrderPayload(),
      spotOpenOrderPayload(),
      spotOpenOrderPayload(symbol: 'ETHUSDT'),
    ]);
    expect(s.orders.length, 2);
  });
  for (final field in ['clientOrderId', 'side', 'status', 'price', 'origQty', 'updateTime']) {
    test('conflicting duplicate $field rejects instead of arrival-order accounting', () {
      final row = spotOpenOrderPayload();
      row[field] = switch (field) {
        'clientOrderId' => 'other',
        'side' => 'SELL',
        'status' => 'PENDING_CANCEL',
        'price' => '1',
        'origQty' => '1',
        _ => spotOrderTime + 1,
      };
      expect(() => map([spotOpenOrderPayload(), row]), throwsFormatException);
    });
  }
  for (final field in ['origQty', 'executedQty', 'price', 'cumQuote', 'avgPrice', 'stopPrice']) {
    test('floating $field rejects at boundary', () {
      final row = spotOpenOrderPayload()..[field] = 0.1;
      expect(() => map([row]), throwsFormatException);
    });
  }
  for (final status in ['FILLED', 'CANCELED', 'EXPIRED', 'REJECTED', 'NOPE']) {
    test('unexpected $status row cannot be represented as current active order', () {
      final row = spotOpenOrderPayload()..['status'] = status;
      expect(() => map([row]), throwsFormatException);
    });
  }
  for (final issue in [
    'zero',
    'overfill',
    'negative',
    'newFill',
    'oldUpdate',
    'idFloat',
    'badSymbol',
    'badClient',
  ]) {
    test('invalid $issue blocks malformed snapshot', () {
      final row = spotOpenOrderPayload();
      switch (issue) {
        case 'zero':
          row['origQty'] = '0';
        case 'overfill':
          row['executedQty'] = '2';
        case 'negative':
          row['price'] = '-1';
        case 'newFill':
          row['executedQty'] = '0.01';
        case 'oldUpdate':
          row['updateTime'] = spotOrderTime - 1;
        case 'idFloat':
          row['orderId'] = 1.0;
        case 'badSymbol':
          row['symbol'] = 'BTC/USDT';
        case 'badClient':
          row['clientOrderId'] = '';
      }
      expect(() => map([row]), throwsFormatException);
    });
  }
  test('partial amount exact; created/update missing stay unknown', () {
    final row = spotOpenOrderPayload()
      ..['status'] = 'PARTIALLY_FILLED'
      ..['executedQty'] = '0.000000000000000001'
      ..['time'] = null
      ..['updateTime'] = null;
    final o = map([row]).orders.single;
    expect(o.remaining.toString(), '0.1');
    expect(o.time, null);
    expect(o.updatedAt, null);
  });
  test('quote-sized market has no guessed base total or remaining quantity', () {
    final row = spotOpenOrderPayload()
      ..['type'] = 'MARKET'
      ..['origType'] = 'MARKET'
      ..['price'] = '0'
      ..['origQty'] = '0'
      ..['origQuoteOrderQty'] = '10.000000000000000001';
    final o = map([row]).orders.single;
    expect(o.remaining, null);
    expect(o.quoteOrderQuantity.toString(), '10.000000000000000001');
  });
  test('Spot event preserves quote fill; O zero never becomes T or E creation time', () {
    final event = mapSpotOpenOrderUpdate(spotNotification(), timeInForce: 'GTC');
    final o = event.order;
    expect(o.quoteFilled.toString(), '8000.001');
    expect(o.time, null);
    expect(o.updatedAt, spotNotification().transactionTime);
    expect(o.units, null);
    expect(o.timeInForce, 'GTC');
    expect(o.orderId, '1917641');
  });
  test('actual creation timestamp and market quote budget retained from event', () {
    final raw = spotNotificationPayload()
      ..['O'] = 100
      ..['o'] = 'MARKET'
      ..['q'] = '0'
      ..['Q'] = '50000.000000000000000001';
    final event = mapSpotOpenOrderUpdate(mapSpotNotification(raw));
    expect(event.order.time!.millisecondsSinceEpoch, 100);
    expect(event.order.remaining, null);
    expect(event.order.quoteOrderQuantity.toString(), '50000.000000000000000001');
  });
  test('missing exchange units remain explicitly unavailable', () {
    final s = mapSpotOpenOrders(
      [spotOpenOrderPayload()],
      address: accountAddress,
      receivedAt: time,
    );
    expect(s.unitsUnavailable, true);
    expect(s.orders.single.units, null);
  });
  test('bounded list and malformed envelope rejected', () {
    expect(() => map({}), throwsFormatException);
    expect(() => map(List.filled(10001, spotOpenOrderPayload())), throwsFormatException);
  });
  for (final v in [0.0, 1.1, -1, 253402300800000, '100']) {
    test('invalid timestamp $v cannot silently become unknown', () {
      final row = spotOpenOrderPayload()..['time'] = v;
      expect(() => map([row]), throwsFormatException);
    });
  }
}

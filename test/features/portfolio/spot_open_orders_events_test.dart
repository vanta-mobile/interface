import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/spot_notification_mapper.dart';
import 'package:vanta/features/portfolio/data/spot_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/spot_open_orders.dart';
import 'package:vanta/features/portfolio/domain/spot_open_orders_event_book.dart';

import '../../support/spot_open_orders.dart';
import '../../support/notifications.dart';

SpotOpenOrderUpdate spotUpdate({
  String id = '9007199254740993',
  String symbol = 'BTCUSDT',
  String status = 'PARTIALLY_FILLED',
  String filled = '0.01',
  int offset = 1,
}) {
  final raw =
      spotNotificationPayload(
          status: status,
          filled: filled,
          last: status == 'PARTIALLY_FILLED' || status == 'FILLED' ? filled : '0',
          time: spotOrderTime + offset,
        )
        ..['T'] = spotOrderTime + offset
        ..['i'] = id
        ..['s'] = symbol
        ..['q'] = '0.100000000000000001'
        ..['x'] = (status == 'PARTIALLY_FILLED' || status == 'FILLED' ? 'TRADE' : status);
  return mapSpotOpenOrderUpdate(mapSpotNotification(raw), timeInForce: 'GTC');
}

void main() {
  test(
    'partial event updates base and quote without changing baseline time or inventing creation',
    () {
      final book = SpotOpenOrdersEventBook(), s = spotOrdersFixture();
      book.add(spotUpdate());
      final next = book.reconcile(s, since: 0),
          o = book.reconcile(s, since: 0).orders.firstWhere((o) => o.symbol == 'BTCUSDT');
      expect(next.receivedAt, s.receivedAt);
      expect(o.time, s.orders.first.time);
      expect(o.executed.toString(), '0.01');
      expect(o.quoteFilled.toString(), '8000.001');
      expect(o.units!.base, 'BTC');
      expect(next.lastEventAt!.millisecondsSinceEpoch, spotOrderTime + 1);
    },
  );
  for (final status in ['FILLED', 'CANCELED', 'EXPIRED', 'REJECTED']) {
    test('$status tombstone survives REST resurrection and later NEW event', () {
      final book = SpotOpenOrdersEventBook();
      final update = status == 'FILLED'
          ? spotUpdate(status: status, filled: '0.100000000000000001')
          : spotUpdate(status: status);
      book.add(update);
      expect(book.reconcile(spotOrdersFixture(), since: 0).orders.length, 1);
      expect(book.add(spotUpdate(status: 'NEW', filled: '0', offset: 50)), false);
      expect(book.reconcile(spotOrdersFixture(), since: book.revision).orders.length, 1);
    });
  }
  test('out of order, duplicate and decreasing fill cannot regress newer state', () {
    final book = SpotOpenOrdersEventBook();
    expect(book.add(spotUpdate(filled: '0.02', offset: 3)), true);
    expect(book.add(spotUpdate(filled: '0.01', offset: 4)), false);
    expect(book.add(spotUpdate(filled: '0.02', offset: 2)), false);
    expect(book.add(spotUpdate(filled: '0.02', offset: 3)), false);
    expect(book.reconcile(spotOrdersFixture(), since: 0).orders.first.executed.toString(), '0.02');
  });
  test('events during REST read reapply; earlier active event cannot add absent order', () {
    final book = SpotOpenOrdersEventBook();
    book.add(spotUpdate(id: '8'));
    final revision = book.revision;
    expect(book.reconcile(spotOrdersFixture(rows: []), since: revision).orders, isEmpty);
    book.add(spotUpdate(id: '9'));
    final s = book.reconcile(spotOrdersFixture(rows: []), since: revision);
    expect(s.orders.single.orderId, '9');
    expect(s.orders.single.time, null);
    expect(s.orders.single.units!.base, 'BTC');
  });
  test(
    'newer REST clock and executed quantity win over older event without local clock comparison',
    () {
      final book = SpotOpenOrdersEventBook();
      book.add(spotUpdate(offset: 2));
      final row = spotOpenOrderPayload()
        ..['updateTime'] = spotOrderTime + 10
        ..['status'] = 'PARTIALLY_FILLED'
        ..['executedQty'] = '0.03';
      final s = spotOrdersFixture(rows: [row]);
      expect(book.reconcile(s, since: 0), same(s));
    },
  );
  test('same ID in another symbol does not share terminal state', () {
    final book = SpotOpenOrdersEventBook();
    book.add(spotUpdate(status: 'CANCELED', filled: '0', id: '7'));
    expect(book.reconcile(spotOrdersFixture(), since: 0).orders.length, 2);
  });
  test('capacity never silently evicts financial tombstones', () {
    final book = SpotOpenOrdersEventBook(capacity: 1);
    book.add(spotUpdate(status: 'CANCELED'));
    expect(() => book.add(spotUpdate(id: '9')), throwsFormatException);
    expect(book.reconcile(spotOrdersFixture(), since: 0).orders.length, 1);
  });
}

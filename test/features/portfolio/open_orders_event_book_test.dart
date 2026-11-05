import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/open_orders_event_book.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/open_order_updates.dart';

void main() {
  test(
    'partial fills update exact remaining size and preserve creation time, units and REST receipt',
    () {
      final original = openOrdersFixture();
      final book = OpenOrdersEventBook();
      expect(book.add(orderUpdate()), true);
      final result = book.reconcile(original, since: 0);
      final order = result.orders.firstWhere((o) => o.symbol == 'BTCUSDT');
      expect(order.time, original.orders.last.time);
      expect(order.units?.base, 'BTC');
      expect(order.remainingQty.toString(), '0.3');
      expect(result.receivedAt, original.receivedAt);
      expect(result.lastEventAt!.millisecondsSinceEpoch, orderEventClock);
      expect(() => result.units.clear(), throwsUnsupportedError);
    },
  );
  test('new order missing from baseline appears only if received during/after that read', () {
    final book = OpenOrdersEventBook();
    book.add(orderUpdate(symbol: 'DELISTEDUSDT', id: '123'));
    expect(book.reconcile(openOrdersFixture(), since: book.revision).orders.length, 2);
    final result = book.reconcile(openOrdersFixture(), since: 0);
    final added = result.orders.singleWhere((o) => o.symbol == 'DELISTEDUSDT');
    expect(added.time, null);
    expect(added.units, null);
    expect(result.orders.length, 3);
  });
  test('E orders each key independently; old, duplicate and regressing fills cannot overwrite', () {
    final book = OpenOrdersEventBook();
    expect(book.add(orderUpdate()), true);
    expect(book.add(orderUpdate()), false);
    expect(book.add(orderUpdate(eventTime: orderEventClock - 1, filled: '0.2')), false);
    expect(book.add(orderUpdate(eventTime: orderEventClock + 1, filled: '0.01')), false);
    expect(
      book.add(orderUpdate(eventTime: orderEventClock + 2, transactionTime: 1, filled: '0.2')),
      false,
    );
    expect(
      book.add(orderUpdate(symbol: 'ETHUSDT', id: '1917642', eventTime: orderEventClock - 10)),
      true,
    );
    expect(book.reconcile(openOrdersFixture(), since: 0).orders.last.executedQty.toString(), '0.1');
  });
  test('terminal tombstones suppress delayed active events and stale REST resurrection', () {
    final book = OpenOrdersEventBook();
    book.add(orderUpdate(status: 'FILLED', filled: '0.40'));
    expect(
      book.reconcile(openOrdersFixture(), since: book.revision).orders.single.symbol,
      'ETHUSDT',
    );
    expect(
      book.add(orderUpdate(status: 'NEW', filled: '0', eventTime: orderEventClock + 2)),
      false,
    );
    expect(
      book.reconcile(openOrdersFixture(), since: book.revision).orders.single.symbol,
      'ETHUSDT',
    );
  });
  test('same E permits a final state to replace partial fill without reversing later', () {
    final book = OpenOrdersEventBook();
    book.add(orderUpdate());
    expect(book.add(orderUpdate(status: 'CANCELED')), true);
    expect(book.add(orderUpdate()), false);
    expect(book.reconcile(openOrdersFixture(), since: 0).orders.length, 1);
  });
  test('newer REST order update outranks a delayed active event; full refresh omits pre-read active events', () {
    final book = OpenOrdersEventBook();
    book.add(orderUpdate());
    book.add(orderUpdate(symbol: 'UNLISTED', id: '5'));
    final row = openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.2')
      ..['updateTime'] = orderEventClock + 1;
    final baseline = mapAsterOpenOrders(
      [row],
      address: accountAddress,
      receivedAt: DateTime.utc(2026, 11, 3),
    );
    final result = book.reconcile(baseline, since: book.revision);
    expect(result.orders.single.executedQty.toString(), '0.2');
    expect(result.lastEventAt, null);
  });
  test(
    'verified final GET blocks any later active event without fabricating cancellation outcome',
    () {
      final book = OpenOrdersEventBook();
      book.closeVerified('BTCUSDT', '1917641');
      expect(book.add(orderUpdate()), false);
      expect(book.reconcile(openOrdersFixture(), since: 0).orders.single.symbol, 'ETHUSDT');
    },
  );
  test('bounded event history rejects overflow without evicting terminal protection', () {
    final book = OpenOrdersEventBook(capacity: 1);
    book.add(orderUpdate(status: 'CANCELED'));
    expect(() => book.add(orderUpdate(id: '2')), throwsFormatException);
    expect(book.reconcile(openOrdersFixture(), since: 0).orders.single.symbol, 'ETHUSDT');
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/features/notifications/domain/notification_status.dart';

import '../../support/aster_account.dart';
import '../../support/notifications.dart';
import '../../support/transfers.dart';

void main() {
  final observedAt = DateTime.now().toUtc();
  TransferNotification transfer(String status) => TransferNotification(
    eventTime: observedAt,
    record: transferRecord(status: status),
  );

  test('design status icons and chip tones follow each event status', () {
    final adl = mapAdl(notificationOrder());
    expect(notificationStatusIcon(transfer('PROCESSING')), NotificationStatusIcon.pending);
    expect(notificationStatusIcon(transfer('SUCCESS')), NotificationStatusIcon.success);
    expect(notificationStatusIcon(transfer('FAILED')), NotificationStatusIcon.failed);
    // Partial fills still wait for the remainder.
    expect(notificationStatusIcon(notificationOrder()), NotificationStatusIcon.pending);
    expect(
      notificationStatusIcon(notificationOrder(status: 'FILLED', filled: '0.4', last: '0.4')),
      NotificationStatusIcon.success,
    );
    for (final status in ['CANCELED', 'EXPIRED']) {
      expect(
        notificationStatusIcon(notificationOrder(status: status, filled: '0', last: '0')),
        NotificationStatusIcon.failed,
      );
    }
    expect(notificationStatusIcon(marginNotification()), NotificationStatusIcon.warning);
    expect(notificationStatusIcon(adl), NotificationStatusIcon.warning);
    expect(notificationTone(transfer('PROCESSING')), NotificationTone.warning);
    expect(notificationTone(transfer('SUCCESS')), NotificationTone.positive);
    expect(notificationTone(transfer('FAILED')), NotificationTone.negative);
    expect(notificationTone(notificationOrder()), NotificationTone.warning);
    expect(notificationTone(marginNotification()), NotificationTone.negative);
    expect(notificationTone(adl), NotificationTone.warning);
    expect(notificationMatches(NotificationFilter.orders, adl), true);
    expect(notificationMatches(NotificationFilter.orders, marginNotification()), false);
    expect(notificationMatches(NotificationFilter.transfers, transfer('FAILED')), true);
  });

  test('a new transfer status refreshes the same entry and marks it unread', () async {
    final repository = LocalNotificationRepository(MemoryNotificationStorage());
    addTearDown(repository.dispose);
    await repository.reload();
    await repository.observeTransfers(accountAddress, [], observedAt, isCurrent: () => true);
    await repository.observeTransfers(
      accountAddress,
      [transferRecord()],
      observedAt,
      isCurrent: () => true,
    );
    await repository.markRead(accountAddress);
    final later = observedAt.add(const Duration(minutes: 1));
    await repository.observeTransfers(
      accountAddress,
      [transferRecord(status: 'SUCCESS')],
      later,
      isCurrent: () => true,
    );
    final entry = repository.snapshot.entries.single;
    expect((entry.event as TransferNotification).record.status, TransferStatus.success);
    expect(entry.event.eventTime, later);
    expect(entry.read, false);
  });

  test('stores with one entry per transfer status decode to the latest status', () {
    final older = InboxEntry(address: accountAddress, event: transfer('PROCESSING'), read: true);
    final newer = InboxEntry(
      address: accountAddress,
      event: TransferNotification(
        eventTime: observedAt.add(const Duration(minutes: 1)),
        record: transferRecord(status: 'SUCCESS'),
      ),
    );
    final decoded = decodeNotifications(encodeNotifications([newer, older]));
    expect((decoded.single.event as TransferNotification).record.status, TransferStatus.success);
    expect(decoded.single.read, false);
    final order = InboxEntry(address: accountAddress, event: notificationOrder());
    final duplicate = jsonDecode(encodeNotifications([order])) as Map<String, dynamic>;
    (duplicate['entries'] as List).add((duplicate['entries'] as List).single);
    expect(() => decodeNotifications(jsonEncode(duplicate)), throwsFormatException);
  });
}

OrderNotification mapAdl(OrderNotification source) => OrderNotification(
  eventTime: source.eventTime,
  transactionTime: source.transactionTime,
  tradeTime: source.tradeTime,
  symbol: source.symbol,
  orderId: source.orderId,
  clientOrderId: 'adl_autoclose',
  side: source.side,
  positionSide: source.positionSide,
  orderType: source.orderType,
  originalType: source.originalType,
  executionType: source.executionType,
  status: source.status,
  quantity: source.quantity,
  price: source.price,
  averagePrice: source.averagePrice,
  lastQuantity: source.lastQuantity,
  filledQuantity: source.filledQuantity,
  lastPrice: source.lastPrice,
  tradeId: source.tradeId,
  realizedPnl: source.realizedPnl,
  reduceOnly: true,
  risk: OrderRisk.adl,
);

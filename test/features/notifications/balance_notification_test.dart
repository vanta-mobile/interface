import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/futures_notification_mapper.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/account_updates.dart';
import '../../support/aster_account.dart';
import '../../support/notifications.dart';

void main() {
  test('balance events retain exact facts, absent change and round-trip local storage', () {
    final absent = accountBalanceUpdate(asset: 'BNB')..remove('bc');
    final source = accountUpdatePayload(
      balances: [
        accountBalanceUpdate(wallet: '0.000000000000000001'),
        absent,
      ],
    );
    final event = mapFuturesNotification(source)! as BalanceNotification;
    expect(event.balances.first.walletBalance.toString(), '0.000000000000000001');
    expect(event.balances.last.change, isNull);
    expect(() => event.balances.clear(), throwsUnsupportedError);
    final decoded =
        decodeNotifications(
              encodeNotifications([InboxEntry(address: accountAddress, event: event)]),
            ).single.event
            as BalanceNotification;
    expect(decoded.dedupeKey, event.dedupeKey);
    expect(decoded.balances.last.change, isNull);
    expect(decoded.transactionTime, event.transactionTime);
    expect(decoded.reason, 'ORDER');
  });

  test('positions alone produce no balance notification and malformed balances fail', () {
    expect(mapFuturesNotification(accountUpdatePayload(balances: [])), isNull);
    for (final balances in [
      [accountBalanceUpdate()..['bc'] = 'NaN'],
      [accountBalanceUpdate()..['wb'] = 1.2],
      [accountBalanceUpdate(), accountBalanceUpdate()],
    ]) {
      expect(
        () => mapFuturesNotification(accountUpdatePayload(balances: balances)),
        throwsFormatException,
      );
    }
  });

  test('replay dedup and read state survive reopening the local repository', () async {
    final storage = MemoryNotificationStorage();
    final inbox = LocalNotificationRepository(storage);
    await inbox.reload();
    final event = mapFuturesNotification(accountUpdatePayload())!;
    await inbox.add(accountAddress, event);
    final key = inbox.snapshot.entries.single.key;
    await inbox.markRead(accountAddress, key: key);
    await inbox.add(accountAddress, mapFuturesNotification(accountUpdatePayload())!);
    expect(inbox.snapshot.entries.length, 1);
    await inbox.dispose();
    final reopened = LocalNotificationRepository(storage);
    addTearDown(reopened.dispose);
    await reopened.reload();
    expect(reopened.snapshot.entries.single.read, isTrue);
    expect(reopened.snapshot.entries.single.key, key);
  });
}

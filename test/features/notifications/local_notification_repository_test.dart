import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/aster_account.dart';
import '../../support/notifications.dart';

const otherAddress = '0x3333333333333333333333333333333333333333';
void main() {
  late MemoryNotificationStorage storage;
  late LocalNotificationRepository repository;
  setUp(() {
    storage = MemoryNotificationStorage();
    repository = LocalNotificationRepository(storage);
  });
  tearDown(() => repository.dispose());
  test('persists multiple fills, keeps replay read and survives repository recreation', () async {
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    final key = repository.snapshot.entries.single.key;
    await repository.markRead(accountAddress, key: key);
    await repository.add(
      accountAddress.toUpperCase().replaceFirst('0X', '0x'),
      notificationOrder(),
    );
    expect(repository.snapshot.entries.single.read, true);
    await repository.add(accountAddress, notificationOrder(tradeId: 43, filled: '0.2'));
    expect(repository.snapshot.entries.length, 2);
    final restarted = LocalNotificationRepository(storage);
    addTearDown(restarted.dispose);
    await restarted.reload();
    expect(restarted.snapshot.entries.length, 2);
    expect(restarted.snapshot.entries.where((e) => e.read).length, 1);
  });
  test('same events and mark-all-read remain account scoped', () async {
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    await repository.add(otherAddress, notificationOrder());
    await repository.markRead(accountAddress);
    expect(repository.snapshot.entries.length, 2);
    expect(repository.snapshot.entries.singleWhere((e) => e.address == accountAddress).read, true);
    expect(repository.snapshot.entries.singleWhere((e) => e.address == otherAddress).read, false);
    await repository.markRead(
      otherAddress,
      key: repository.snapshot.entries.firstWhere((e) => e.address == accountAddress).key,
    );
    expect(repository.snapshot.entries.singleWhere((e) => e.address == otherAddress).read, false);
  });
  test(
    'initial-load race queues new events and read changes without replacing stored history',
    () async {
      storage.value = encodeNotifications([
        InboxEntry(address: otherAddress, event: marginNotification()),
      ]);
      storage.readGate = Completer<void>();
      final load = repository.reload();
      final add = repository.add(accountAddress, notificationOrder());
      final read = repository.markRead(accountAddress);
      await Future<void>.delayed(Duration.zero);
      expect(repository.snapshot.loaded, false);
      storage.readGate!.complete();
      await Future.wait([load, add, read]);
      final saved = decodeNotifications(storage.value);
      expect(saved.length, 2);
      expect(saved.singleWhere((e) => e.address == accountAddress).read, true);
      expect(saved.singleWhere((e) => e.address == otherAddress).read, false);
    },
  );
  test('failed initial read retains live events in memory and never overwrites disk', () async {
    storage.value = encodeNotifications([
      InboxEntry(address: otherAddress, event: marginNotification()),
    ]);
    final original = storage.value;
    storage.failRead = true;
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    await repository.markRead(accountAddress);
    expect(repository.snapshot.storageFailed, true);
    expect(repository.snapshot.loaded, false);
    expect(repository.snapshot.entries.single.read, true);
    expect(storage.value, original);
    expect(storage.writes, 0);
    storage.failRead = false;
    await repository.reload();
    expect(repository.snapshot.storageFailed, false);
    expect(repository.snapshot.entries.length, 2);
    expect(decodeNotifications(storage.value).length, 2);
  });
  test('replay during failed load preserves persisted read status after recovery', () async {
    storage.value = encodeNotifications([
      InboxEntry(address: accountAddress, event: notificationOrder(), read: true),
    ]);
    storage.failRead = true;
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    storage.failRead = false;
    await repository.reload();
    expect(repository.snapshot.entries.single.read, true);
  });
  test('malformed and future-version storage remains untouched and retryable', () async {
    for (final raw in ['{corrupt', '{"version":2,"entries":[]}']) {
      final isolated = MemoryNotificationStorage()..value = raw;
      final repo = LocalNotificationRepository(isolated);
      await repo.reload();
      await repo.add(accountAddress, notificationOrder());
      expect(repo.snapshot.storageFailed, true);
      expect(isolated.value, raw);
      expect(isolated.writes, 0);
      await repo.dispose();
    }
  });
  test('failed write preserves in-memory event/read state and retry saves latest state', () async {
    await repository.reload();
    storage.failWrite = true;
    await repository.add(accountAddress, notificationOrder());
    await repository.markRead(accountAddress);
    expect(repository.snapshot.storageFailed, true);
    expect(repository.snapshot.entries.single.read, true);
    storage.failWrite = false;
    await repository.reload();
    expect(repository.snapshot.storageFailed, false);
    expect(decodeNotifications(storage.value).single.read, true);
    expect(storage.reads, 1);
  });
  test('writes are serialized, so an earlier delayed write cannot replace a later read', () async {
    await repository.reload();
    storage.writeGate = Completer<void>();
    final add = repository.add(accountAddress, notificationOrder());
    final read = repository.markRead(accountAddress);
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, 1);
    storage.writeGate!.complete();
    await Future.wait([add, read]);
    expect(decodeNotifications(storage.value).single.read, true);
  });
  test('bounded recent history sorts events by event time and retains later fills', () async {
    // Populate a valid maximum-sized persisted snapshot rather than 500 disk writes.
    storage.value = encodeNotifications(
      List.generate(
        notificationLimit,
        (i) => InboxEntry(
          address: accountAddress,
          event: notificationOrder(tradeId: i + 1, time: 1000 + i),
        ),
      ),
    );
    await repository.reload();
    await repository.add(accountAddress, notificationOrder(tradeId: 9999, time: 9000));
    final entries = repository.snapshot.entries;
    expect(entries.length, notificationLimit);
    expect(entries.first.event.eventTime.millisecondsSinceEpoch, 9000);
    expect(entries.last.event.eventTime.millisecondsSinceEpoch, 1001);
    expect(utf8.encode(storage.value!).length, lessThanOrEqualTo(notificationByteLimit));
  });
  test('snapshots and entry collections cannot be modified by consumers', () async {
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    expect(() => repository.snapshot.entries.clear(), throwsUnsupportedError);
  });
  test('disposing listeners lets accepted writes finish and refuses new events', () async {
    await repository.reload();
    storage.writeGate = Completer<void>();
    final first = repository.add(accountAddress, notificationOrder());
    final second = repository.add(accountAddress, notificationOrder(tradeId: 43));
    await Future<void>.delayed(Duration.zero);
    await repository.dispose();
    storage.writeGate!.complete();
    await Future.wait([first, second]);
    expect(decodeNotifications(storage.value).length, 2);
    await repository.add(accountAddress, notificationOrder(tradeId: 44));
    expect(decodeNotifications(storage.value).length, 2);
  });
}

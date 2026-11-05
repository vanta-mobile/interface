import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/data/notification_store_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/features/notifications/domain/transfer_observation.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/notifications.dart';
import '../../support/transfers.dart';

const anotherWallet = '0x3333333333333333333333333333333333333333';
final observedAt = DateTime.utc(2026, 11, 3);

void main() {
  late MemoryNotificationStorage storage;
  late LocalNotificationRepository repository;
  setUp(() {
    storage = MemoryNotificationStorage();
    repository = LocalNotificationRepository(storage);
  });
  tearDown(() => repository.dispose());

  test(
    'first history becomes silent baseline; a later status change is notified once across restart',
    () async {
      await repository.reload();
      expect(
        await repository.observeTransfers(
          accountAddress,
          [transferRecord()],
          observedAt,
          isCurrent: () => true,
        ),
        true,
      );
      expect(repository.snapshot.entries, isEmpty);
      final baseline = decodeNotificationStore(storage.value);
      expect(baseline.baselines[accountAddress]!.values.single.record.status.name, 'processing');
      await repository.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS', hash: '0x123')],
        observedAt,
        isCurrent: () => true,
      );
      final event = repository.snapshot.entries.single.event as TransferNotification;
      expect(event.record.recordTime, isNot(event.eventTime));
      expect(event.eventType, 'DEPOSIT_SUCCESS');
      await repository.markRead(accountAddress);
      final restarted = LocalNotificationRepository(storage);
      addTearDown(restarted.dispose);
      await restarted.reload();
      await restarted.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS', hash: '0x123')],
        observedAt,
        isCurrent: () => true,
      );
      expect(restarted.snapshot.entries.single.read, true);
      expect(restarted.snapshot.entries.single.key, repository.snapshot.entries.single.key);
    },
  );
  test('an empty initial response establishes baseline for both markets and types', () async {
    await repository.reload();
    await repository.observeTransfers(accountAddress, [], observedAt, isCurrent: () => true);
    await repository.observeTransfers(
      accountAddress,
      [transferRecord(), transferRecord(market: 'spot'), transferRecord(type: 'WITHDRAW')],
      observedAt,
      isCurrent: () => true,
    );
    expect(repository.snapshot.entries.length, 3);
    expect(repository.snapshot.entries.map((e) => e.key).toSet().length, 3);
    await repository.observeTransfers(
      anotherWallet,
      [transferRecord(status: 'SUCCESS')],
      observedAt,
      isCurrent: () => true,
    );
    expect(repository.snapshot.entries.length, 3); // New wallet starts silently.
    await repository.observeTransfers(
      anotherWallet,
      [transferRecord(status: 'SUCCESS'), transferRecord(id: 'new')],
      observedAt,
      isCurrent: () => true,
    );
    expect(repository.snapshot.entries.where((e) => e.address == anotherWallet).length, 1);
  });
  test('missing records retain all observed states without assuming a transition order', () async {
    await repository.reload();
    await repository.observeTransfers(
      accountAddress,
      [transferRecord(status: 'SUCCESS')],
      observedAt,
      isCurrent: () => true,
    );
    await repository.observeTransfers(accountAddress, [], observedAt, isCurrent: () => true);
    for (final state in ['PROCESSING', 'FAILED', 'SUCCESS', 'FAILED', 'PROCESSING']) {
      await repository.observeTransfers(
        accountAddress,
        [transferRecord(status: state)],
        observedAt,
        isCurrent: () => true,
      );
    }
    expect(
      repository.snapshot.entries.length,
      2,
    ); // Baseline SUCCESS stays silent, other states once.
    expect(
      decodeNotificationStore(storage.value).baselines[accountAddress]!.values.single.states.length,
      3,
    );
  });
  test(
    'late or replaced hash updates metadata silently; missing hash remains unknown in new reports',
    () async {
      await repository.reload();
      await repository.observeTransfers(
        accountAddress,
        [transferRecord()],
        observedAt,
        isCurrent: () => true,
      );
      for (final hash in ['0x123', '0x456']) {
        await repository.observeTransfers(
          accountAddress,
          [transferRecord(hash: hash)],
          observedAt,
          isCurrent: () => true,
        );
        expect(
          decodeNotificationStore(storage.value)
              .baselines[accountAddress]!
              .values
              .single
              .record
              .txHash,
          hash,
        );
      }
      expect(repository.snapshot.entries, isEmpty);
      await repository.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS')],
        observedAt,
        isCurrent: () => true,
      );
      expect(
        (repository.snapshot.entries.single.event as TransferNotification).record.txHash,
        null,
      );
    },
  );
  test('duplicate IDs reject the whole observation including otherwise new records', () async {
    await repository.reload();
    await repository.observeTransfers(
      accountAddress,
      [transferRecord()],
      observedAt,
      isCurrent: () => true,
    );
    final original = storage.value;
    await expectLater(
      repository.observeTransfers(
        accountAddress,
        [transferRecord(id: 'new'), transferRecord(), transferRecord(status: 'SUCCESS')],
        observedAt,
        isCurrent: () => true,
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(storage.value, original);
    expect(repository.snapshot.entries, isEmpty);
  });
  test(
    'notification pruning does not erase state deduplication across repository recreation',
    () async {
      storage.value = encodeNotificationStore(
        List.generate(
          notificationLimit,
          (i) => InboxEntry(
            address: accountAddress,
            event: notificationOrder(
              tradeId: i + 1,
              time: observedAt.millisecondsSinceEpoch + 10000 + i,
            ),
          ),
        ),
        {
          accountAddress: {
            transferRecord().key: TransferObservation(transferRecord(), [transferRecord().status]),
          },
        },
      );
      await repository.reload();
      await repository.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS')],
        observedAt,
        isCurrent: () => true,
      );
      expect(repository.snapshot.entries.every((e) => e.event is OrderNotification), true);
      final restarted = LocalNotificationRepository(storage);
      addTearDown(restarted.dispose);
      await restarted.reload();
      await restarted.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS')],
        observedAt.add(const Duration(days: 1)),
        isCurrent: () => true,
      );
      expect(restarted.snapshot.entries.every((e) => e.event is OrderNotification), true);
      expect(restarted.snapshot.entries.length, notificationLimit);
    },
  );
  test('failed initial storage blocks baseline without overwriting old notifications', () async {
    storage.value = encodeNotifications([
      InboxEntry(address: accountAddress, event: notificationOrder()),
    ]);
    final original = storage.value;
    storage.failRead = true;
    await repository.reload();
    await expectLater(
      repository.observeTransfers(
        accountAddress,
        [transferRecord()],
        observedAt,
        isCurrent: () => true,
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(storage.value, original);
    expect(storage.writes, 0);
    storage.failRead = false;
    await repository.reload();
    await repository.observeTransfers(
      accountAddress,
      [transferRecord()],
      observedAt,
      isCurrent: () => true,
    );
    expect(repository.snapshot.entries.length, 1);
  });
  test('v1 read state survives upgrade and a transfer write failure retries inbox and baseline together', () async {
    storage.value = encodeNotifications([
      InboxEntry(address: accountAddress, event: notificationOrder(), read: true),
    ]);
    await repository.reload();
    await repository.observeTransfers(
      accountAddress,
      [transferRecord()],
      observedAt,
      isCurrent: () => true,
    );
    final old = storage.value;
    storage.failWrite = true;
    await repository.observeTransfers(
      accountAddress,
      [transferRecord(status: 'FAILED')],
      observedAt,
      isCurrent: () => true,
    );
    expect(storage.value, old);
    expect(repository.snapshot.storageFailed, true);
    expect(repository.snapshot.entries.length, 2);
    storage.failWrite = false;
    await repository.reload();
    final saved = decodeNotificationStore(storage.value);
    expect(saved.entries.length, 2);
    expect(saved.entries.singleWhere((e) => e.event is OrderNotification).read, true);
    expect(saved.baselines[accountAddress]!.values.single.record.status.name, 'failed');
  });
  test(
    'an interrupted failed write can replay once from last durable baseline after restart',
    () async {
      await repository.reload();
      await repository.observeTransfers(
        accountAddress,
        [transferRecord()],
        observedAt,
        isCurrent: () => true,
      );
      storage.failWrite = true;
      await repository.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS')],
        observedAt,
        isCurrent: () => true,
      );
      storage.failWrite = false;
      final restarted = LocalNotificationRepository(storage);
      addTearDown(restarted.dispose);
      await restarted.reload();
      await restarted.observeTransfers(
        accountAddress,
        [transferRecord(status: 'SUCCESS')],
        observedAt,
        isCurrent: () => true,
      );
      expect(restarted.snapshot.entries.length, 1);
    },
  );
  test(
    'queue combines live events, transfer changes and read flags in the same stored value',
    () async {
      await repository.reload();
      await repository.observeTransfers(accountAddress, [], observedAt, isCurrent: () => true);
      storage.writeGate = Completer<void>();
      final observed = repository.observeTransfers(
        accountAddress,
        [transferRecord()],
        observedAt,
        isCurrent: () => true,
      );
      final live = repository.add(accountAddress, notificationOrder());
      final read = repository.markRead(accountAddress);
      await Future<void>.delayed(Duration.zero);
      storage.writeGate!.complete();
      await Future.wait([observed, live, read]);
      final store = decodeNotificationStore(storage.value);
      expect(store.entries.length, 2);
      expect(store.entries.every((e) => e.read), true);
      expect(store.baselines[accountAddress]!.length, 1);
    },
  );
  test(
    'identity change while observation waits in storage queue prevents any baseline commit',
    () async {
      await repository.reload();
      storage.writeGate = Completer<void>();
      final live = repository.add(accountAddress, notificationOrder());
      var current = true;
      final observed = repository.observeTransfers(
        accountAddress,
        [transferRecord()],
        observedAt,
        isCurrent: () => current,
      );
      final checked = expectLater(observed, throwsA(isA<AccountReadFailure>()));
      await Future<void>.delayed(Duration.zero);
      current = false;
      storage.writeGate!.complete();
      await Future.wait([live, checked]);
      expect(decodeNotificationStore(storage.value).baselines, isEmpty);
    },
  );
  test('malformed baseline remains untouched and never becomes an empty replacement', () async {
    for (final mutation in [
      'extra',
      'duplicate',
      'wrongWallet',
      'amount',
      'version',
      'floatVersion',
      'missingState',
      'duplicateState',
      'unknownState',
    ]) {
      final raw = jsonDecode(
        encodeNotificationStore([], {
          accountAddress: {
            transferRecord().key: TransferObservation(transferRecord(), [transferRecord().status]),
          },
        }),
      ) as Map<String, dynamic>;
      final wallets = raw['transfers'] as Map;
      final records = wallets[accountAddress] as List;
      switch (mutation) {
        case 'extra':
          ((records.single as Map)['record'] as Map)['secret'] = 'unsafe';
        case 'duplicate':
          records.add(records.single);
        case 'wrongWallet':
          wallets['0xBAD'] = records;
        case 'amount':
          ((records.single as Map)['record'] as Map)['amount'] = 1.2;
        case 'version':
          raw['version'] = 99;
        case 'floatVersion':
          raw['version'] = 2.0;
        case 'missingState':
          (records.single as Map)['states'] = <String>[];
        case 'duplicateState':
          (records.single as Map)['states'] = ['processing', 'processing'];
        case 'unknownState':
          (records.single as Map)['states'] = ['processing', 'unknown'];
      }
      final source = jsonEncode(raw);
      final isolated = MemoryNotificationStorage()..value = source;
      final repo = LocalNotificationRepository(isolated);
      await repo.reload();
      await repo.add(accountAddress, notificationOrder());
      expect(repo.snapshot.loaded, false);
      expect(repo.snapshot.storageFailed, true);
      expect(isolated.value, source);
      await repo.dispose();
    }
  });
  test(
    'bounded ledger refuses excessive history without pruning prior observations or inbox',
    () async {
      await repository.reload();
      await repository.add(accountAddress, notificationOrder());
      final original = storage.value;
      await expectLater(
        repository.observeTransfers(
          accountAddress,
          List.generate(5000, (i) => transferRecord(id: 'record-$i', hash: 'x' * 256)),
          observedAt,
          isCurrent: () => true,
        ),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'transferTrackingFull')),
      );
      expect(storage.value, original);
      expect(repository.snapshot.entries.length, 1);
    },
  );
}

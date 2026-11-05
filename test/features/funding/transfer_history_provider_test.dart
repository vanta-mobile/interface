import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_store_codec.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/data/account_update_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/transfers.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestTransferHistoryRepository history;
  late LocalNotificationRepository inbox;
  late MemoryNotificationStorage storage;
  late TestAccountChangeRepository changes;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    history = TestTransferHistoryRepository();
    storage = MemoryNotificationStorage();
    inbox = LocalNotificationRepository(storage);
    changes = TestAccountChangeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        transferHistoryRepositoryProvider.overrideWithValue(history),
        notificationRepositoryProvider.overrideWithValue(inbox),
        accountChangeRepositoryProvider.overrideWithValue(changes),
        accountChangeClockProvider.overrideWithValue(() => changes.now),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await inbox.dispose();
    await identity.dispose();
    await changes.dispose();
  });
  Future<void> start() async {
    container.read(authProvider);
    container.read(transferHistoryProvider);
    container.read(notificationInboxProvider);
    await Future<void>.delayed(Duration.zero);
  }

  TransferHistoryController controller() => container.read(transferHistoryProvider.notifier);

  test(
    'opening makes no private request; explicit baseline then state refresh creates one notice',
    () async {
      await start();
      expect(history.calls, 0);
      await controller().refresh();
      expect(history.calls, 1);
      expect(container.read(transferHistoryProvider).initialBaseline, true);
      expect(container.read(walletNotificationsProvider), isEmpty);
      history.records = [transferRecord(status: 'SUCCESS')];
      await controller().refresh();
      expect(container.read(transferHistoryProvider).initialBaseline, false);
      expect(container.read(walletNotificationsProvider).length, 1);
      expect(identity.wallets, 0);
    },
  );
  test('storage failure prevents signature requests, and retry preserves existing state', () async {
    storage.failRead = true;
    await start();
    await controller().refresh();
    expect(history.calls, 0);
    expect(container.read(transferHistoryProvider).failure?.key, 'transferStorageRequired');
    storage.failRead = false;
    await controller().refresh();
    expect(history.calls, 1);
    expect(container.read(transferHistoryProvider).failure, null);
  });
  test('failed save surfaces recoverable history and flushes baseline before next read', () async {
    await start();
    storage.failWrite = true;
    await controller().refresh();
    expect(container.read(transferHistoryProvider).account, isNotNull);
    expect(container.read(transferHistoryProvider).failure?.key, 'transferStorageRequired');
    storage.failWrite = false;
    history.records = [transferRecord(status: 'SUCCESS')];
    await controller().refresh();
    expect(container.read(transferHistoryProvider).failure, null);
    expect(decodeNotificationStore(storage.value).entries.length, 1);
  });
  test('refusal preserves displayed history; repeat taps cannot create parallel reads', () async {
    await start();
    await controller().refresh();
    final previous = container.read(transferHistoryProvider).account;
    history.gate = Completer<void>();
    history.failure = const AccountReadFailure('authWalletRejected');
    final pending = controller().refresh();
    await controller().refresh();
    expect(history.calls, 2);
    history.gate!.complete();
    await pending;
    expect(container.read(transferHistoryProvider).account, same(previous));
    expect(container.read(transferHistoryProvider).failure?.key, 'authWalletRejected');
    expect(container.read(transferHistoryProvider).busy, false);
  });
  test(
    'new account, logout and signing loss discard late data without establishing a baseline',
    () async {
      await start();
      history.gate = Completer<void>();
      final pending = controller().refresh();
      await Future<void>.delayed(Duration.zero);
      identity.events.add(identityWithWallet);
      await Future<void>.delayed(Duration.zero);
      history.gate!.complete();
      await pending;
      expect(container.read(transferHistoryProvider).account, null);
      expect(decodeNotificationStore(storage.value).baselines, isEmpty);
      await controller().refresh();
      expect(container.read(transferHistoryProvider).failure?.key, 'authWalletReconnect');
      expect(history.calls, 1);
    },
  );
  test('stop waiting discards a late payload and permits a subsequent read', () async {
    await start();
    history.gate = Completer<void>();
    final pending = controller().refresh();
    await Future<void>.delayed(Duration.zero);
    controller().stop();
    history.gate!.complete();
    await pending;
    expect(container.read(transferHistoryProvider).failure?.key, 'historyReadStopped');
    expect(decodeNotificationStore(storage.value).baselines, isEmpty);
    await controller().refresh();
    expect(container.read(transferHistoryProvider).account, isNotNull);
  });
  test(
    'transfer events retain reason/bc and request refresh without signing or duplicating notices',
    () async {
      await start();
      await controller().refresh();
      final monitor = container.read(accountChangeProvider.notifier);
      await monitor.authorize();
      changes.channels.single.add(const AccountChangeEvent.connected());
      for (final reason in ['DEPOSIT', 'WITHDRAW', 'WITHDRAW_REJECT']) {
        await controller().refresh();
        final update = mapAccountUpdate({
          'e': 'ACCOUNT_UPDATE',
          'E': 1793620800123,
          'T': 1793620800122,
          'a': {
            'm': reason,
            'B': [
              {'a': 'USDT', 'wb': '100', 'cw': '90', 'bc': '-0.000000000000000001'},
            ],
          },
        });
        expect(update.reason, reason);
        expect(update.balances.single.change.toString(), '-0.000000000000000001');
        final calls = history.calls;
        changes.channels.single.add(
          AccountChangeEvent.changed(AccountChangeKind.account, update.eventTime, account: update),
        );
        expect(container.read(transferHistoryProvider).stale, true);
        expect(history.calls, calls);
        expect(container.read(walletNotificationsProvider), isEmpty);
      }
      expect(identity.wallets, 0);
      expect(changes.authorizations, 1);
    },
  );
  test(
    'refresh hint during a read survives completion and unrelated reasons do not create it',
    () async {
      await start();
      await controller().refresh();
      final monitor = container.read(accountChangeProvider.notifier);
      await monitor.authorize();
      changes.channels.single.add(const AccountChangeEvent.connected());
      final update = mapAccountUpdate({
        'e': 'ACCOUNT_UPDATE',
        'E': 1793620800123,
        'T': 1793620800122,
        'a': {
          'm': 'ORDER',
          'B': [
            {'a': 'USDT', 'wb': '100', 'cw': '90', 'bc': '0'},
          ],
        },
      });
      changes.channels.single.add(
        AccountChangeEvent.changed(AccountChangeKind.account, update.eventTime, account: update),
      );
      expect(container.read(transferHistoryProvider).stale, false);
      history.gate = Completer<void>();
      final pending = controller().refresh();
      controller().markRefreshNeeded();
      history.gate!.complete();
      await pending;
      expect(container.read(transferHistoryProvider).stale, true);
    },
  );
  test('returned wallet mismatch does not update persistence or expose a snapshot', () async {
    await start();
    history.returnedAddress = '0x3333333333333333333333333333333333333333';
    await controller().refresh();
    expect(container.read(transferHistoryProvider).failure?.key, 'authWalletChanged');
    expect(container.read(transferHistoryProvider).account, null);
    expect(decodeNotificationStore(storage.value).baselines, isEmpty);
  });
}

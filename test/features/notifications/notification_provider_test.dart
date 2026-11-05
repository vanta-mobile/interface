import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';

const other = AuthIdentity(
  id: 'other',
  walletAddress: '0x3333333333333333333333333333333333333333',
  walletKind: WalletKind.external,
  signingAvailable: true,
);
void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestAccountChangeRepository changes;
  late LocalNotificationRepository repository;
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await repository.reload();
  }

  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    changes = TestAccountChangeRepository();
    repository = LocalNotificationRepository(MemoryNotificationStorage());
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountChangeRepositoryProvider.overrideWithValue(changes),
        accountChangeClockProvider.overrideWithValue(() => changes.now),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(authProvider);
    container.read(accountChangeProvider);
    container.read(walletNotificationsProvider);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await changes.dispose();
    await repository.dispose();
  });
  test(
    'opening the inbox signs nothing; only explicitly enabled live stream adds notifications',
    () async {
      await flush();
      expect(changes.authorizations, 0);
      expect(changes.channels, isEmpty);
      expect(container.read(unreadNotificationsProvider), 0);
      await container.read(accountChangeProvider.notifier).authorize();
      final event = notificationOrder();
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
      );
      await flush();
      expect(container.read(unreadNotificationsProvider), 1);
      await container.read(notificationInboxProvider.notifier).markRead();
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
      );
      await flush();
      expect(container.read(unreadNotificationsProvider), 0);
      expect(container.read(walletNotificationsProvider).length, 1);
      expect(changes.authorizations, 1);
      expect(identity.wallets, 0);
    },
  );
  test('multiple fills and margin risk ingested even with no notification route open', () async {
    await flush();
    await container.read(accountChangeProvider.notifier).authorize();
    for (final event in [
      notificationOrder(),
      notificationOrder(tradeId: 43, filled: '0.2'),
      marginNotification(),
    ]) {
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
      );
    }
    await flush();
    expect(container.read(walletNotificationsProvider).length, 3);
    expect(container.read(unreadNotificationsProvider), 3);
    expect(changes.authorizations, 1);
  });
  test(
    'wallet switch hides old inbox immediately and old stream cannot attribute to new wallet',
    () async {
      await flush();
      await container.read(accountChangeProvider.notifier).authorize();
      final oldChannel = changes.channels.last, event = notificationOrder();
      oldChannel.add(
        AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
      );
      await flush();
      identity.events.add(other);
      expect(container.read(walletNotificationsProvider), isEmpty);
      oldChannel.add(
        AccountChangeEvent.changed(
          AccountChangeKind.order,
          event.eventTime,
          notification: notificationOrder(tradeId: 43, filled: '0.2'),
        ),
      );
      await flush();
      expect(container.read(walletNotificationsProvider), isEmpty);
      await container.read(accountChangeProvider.notifier).authorize();
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
      );
      await flush();
      expect(container.read(walletNotificationsProvider).single.address, other.walletAddress);
      await container.read(notificationInboxProvider.notifier).markRead();
      identity.events.add(signingIdentity);
      expect(container.read(unreadNotificationsProvider), 1);
      identity.events.add(null);
      expect(container.read(walletNotificationsProvider), isEmpty);
      expect(repository.snapshot.entries.length, 2);
      expect(identity.wallets, 0);
    },
  );
  test('stopped/expired stream never ingests later events or signs on reconnect', () async {
    await flush();
    final controller = container.read(accountChangeProvider.notifier);
    await controller.authorize();
    final channel = changes.channels.last;
    channel.add(const AccountChangeEvent.expired());
    final event = notificationOrder();
    channel.add(
      AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
    );
    controller.reconnect();
    await flush();
    expect(repository.snapshot.entries, isEmpty);
    expect(changes.authorizations, 1);
    expect(changes.channels.length, 1);
  });
}

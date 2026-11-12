import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_provider.dart';
import 'package:vanta/features/portfolio/application/spot_history_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';
import '../../support/spot_history.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestAccountChangeRepository spot, perp;
  late LocalNotificationRepository inbox;
  setUp(() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    spot = TestAccountChangeRepository();
    perp = TestAccountChangeRepository();
    inbox = LocalNotificationRepository(MemoryNotificationStorage());
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        asterSpotRepositoryProvider.overrideWithValue(TestSpotRepository()),
        spotHistoryRepositoryProvider.overrideWithValue(TestSpotHistoryRepository()),
        spotHistoryClockProvider.overrideWithValue(() => historyNow),
        accountChangeRepositoryProvider.overrideWithValue(perp),
        spotAccountChangeRepositoryProvider.overrideWithValue(spot),
        accountChangeClockProvider.overrideWithValue(() => spot.now),
        notificationRepositoryProvider.overrideWithValue(inbox),
      ],
    );
    container.read(authProvider);
    container.read(accountChangeProvider);
    container.read(spotAccountChangeProvider);
    container.read(notificationInboxProvider);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
    await spot.dispose();
    await perp.dispose();
    await inbox.dispose();
  });
  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await inbox.reload();
  }

  Future<void> readSnapshots() async {
    await container.read(spotAccountReadProvider.notifier).refresh();
    await container.read(spotHistoryProvider.notifier).refresh();
    expect(container.read(spotAccountReadProvider).stale, false);
    expect(container.read(spotHistoryProvider).stale, false);
  }

  SpotAccountChangeController controller() => container.read(spotAccountChangeProvider.notifier);
  AccountChangeState state() => container.read(spotAccountChangeProvider);
  void send(TestAccountChangeRepository source, {bool spotEvent = true, int tradeId = 42}) {
    final event = spotEvent
        ? spotNotification(tradeId: tradeId)
        : notificationOrder(tradeId: tradeId);
    source.channels.last.add(
      AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
    );
  }

  test(
    'Spot starts explicitly and leaves futures stopped; every fill and market has its own identity',
    () async {
      await flush();
      expect(spot.authorizations, 0);
      expect(perp.authorizations, 0);
      await controller().authorize();
      await readSnapshots();
      send(spot);
      send(spot);
      send(spot, tradeId: 43);
      await flush();
      expect(container.read(localJournalUnreadNotificationsProvider), 2);
      expect(container.read(spotAccountReadProvider).stale, true);
      expect(container.read(spotHistoryProvider).stale, true);
      expect(perp.authorizations, 0);
      await container.read(accountChangeProvider.notifier).authorize();
      send(perp, spotEvent: false);
      await flush();
      expect(container.read(localJournalUnreadNotificationsProvider), 3);
      expect(spot.authorizations, 1);
      expect(perp.authorizations, 1);
      expect(identity.wallets, 0);
      await container.read(notificationInboxProvider.notifier).markRead();
      send(spot);
      await flush();
      expect(container.read(localJournalUnreadNotificationsProvider), 0);
    },
  );
  test(
    'Spot disconnect/reconnect and background resume never sign; stopping it leaves futures active',
    () async {
      await flush();
      await controller().authorize();
      await container.read(accountChangeProvider.notifier).authorize();
      spot.channels.last.add(const AccountChangeEvent.connected());
      perp.channels.last.add(const AccountChangeEvent.connected());
      spot.channels.last.addError(StateError('secret transport error'));
      expect(state().failure?.key, 'accountNetwork');
      expect(spot.channels.length, 1);
      controller().reconnect();
      spot.channels.last.add(const AccountChangeEvent.connected());
      expect(spot.channels.length, 2);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      expect(state().connection, AccountChangeConnection.paused);
      container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      expect(spot.channels.length, 3);
      spot.channels.last.add(const AccountChangeEvent.connected());
      controller().stop();
      send(spot);
      await flush();
      expect(inbox.snapshot.entries, isEmpty);
      expect(spot.authorizations, 1);
      expect(perp.authorizations, 1);
      expect(container.read(accountChangeProvider).expiresAt, isNotNull);
    },
  );
  test(
    'wallet switch/logout discards old streams and preserves but hides old local history',
    () async {
      await flush();
      await controller().authorize();
      send(spot);
      await flush();
      final channel = spot.channels.last;
      const other = AuthIdentity(
        id: 'other',
        walletAddress: '0x3333333333333333333333333333333333333333',
        walletKind: WalletKind.external,
        signingAvailable: true,
      );
      identity.events.add(other);
      expect(container.read(walletNotificationsProvider), isEmpty);
      final old = spotNotification(tradeId: 43);
      channel.add(
        AccountChangeEvent.changed(AccountChangeKind.order, old.eventTime, notification: old),
      );
      await flush();
      expect(inbox.snapshot.entries.length, 1);
      await controller().authorize();
      send(spot);
      await flush();
      expect(container.read(walletNotificationsProvider).single.address, other.walletAddress);
      identity.events.add(null);
      expect(container.read(walletNotificationsProvider), isEmpty);
      identity.restored = signingIdentity;
      await container.read(authProvider.notifier).bootstrap();
      expect(container.read(localJournalUnreadNotificationsProvider), 1);
      expect(identity.wallets, 0);
    },
  );
  test('refusal, lost signer and stop during signing never create a stream', () async {
    await flush();
    spot.failure = const AccountReadFailure('authWalletRejected');
    await controller().authorize();
    expect(state().failure?.key, 'authWalletRejected');
    expect(spot.channels, isEmpty);
    spot.failure = null;
    spot.gate = Completer<void>();
    final pending = controller().authorize();
    controller().stop();
    spot.gate!.complete();
    await pending;
    expect(spot.channels, isEmpty);
    identity.events.add(
      const AuthIdentity(
        id: 'readonly',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      ),
    );
    await controller().authorize();
    expect(state().failure?.key, 'authWalletReconnect');
    expect(spot.channels, isEmpty);
  });
  test(
    'outbound account signals invalidate snapshots but create no completed transfer notice',
    () async {
      await flush();
      await controller().authorize();
      await readSnapshots();
      spot.channels.last.add(AccountChangeEvent.changed(AccountChangeKind.account, spot.now));
      await flush();
      expect(container.read(spotAccountReadProvider).stale, true);
      expect(inbox.snapshot.entries, isEmpty);
    },
  );
  testWidgets('Spot renewal reminder at 50 minutes and hard local expiry at 60 never auto-sign', (
    tester,
  ) async {
    await tester.pump();
    await controller().authorize();
    spot.channels.last.add(const AccountChangeEvent.connected());
    spot.now = spot.now.add(const Duration(minutes: 50));
    await tester.pump(const Duration(minutes: 50));
    expect(state().renewalDue, true);
    expect(spot.authorizations, 1);
    spot.now = spot.now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(minutes: 10));
    expect(state().connection, AccountChangeConnection.expired);
    send(spot);
    await tester.pump();
    controller().reconnect();
    expect(spot.authorizations, 1);
    expect(inbox.snapshot.entries, isEmpty);
    container.dispose();
    container = ProviderContainer();
  });
}

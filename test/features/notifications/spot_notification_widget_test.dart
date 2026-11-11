import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/spot_notification_mapper.dart';
import 'package:vanta/features/notifications/presentation/notification_details.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/features/notifications/presentation/spot_notification_details.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/spot_account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> show(WidgetTester tester, Finder finder, String key) async {
    final scroll = find
        .descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(finder, 200, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'zh']) {
    testWidgets(
      'Spot details use own units, exact quote amounts, no long/short and preserve wallet isolation: $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = LocalNotificationRepository(MemoryNotificationStorage());
        final spot = TestAccountChangeRepository(), perp = TestAccountChangeRepository();
        final units = TestSpotNotificationUnitsRepository();
        addTearDown(identity.dispose);
        addTearDown(repository.dispose);
        addTearDown(spot.dispose);
        addTearDown(perp.dispose);
        final source = spotNotificationPayload()
          ..addAll({'Y': '0.000000000000000001', 'Z': '0.200000000000000001', 'ps': 'LONG'});
        final event = mapSpotNotification(source);
        await repository.reload();
        await repository.add(accountAddress, event);
        await repository.add(accountAddress, notificationOrder());
        final record = repository.snapshot.entries.firstWhere((e) => e.event == event);
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          notificationRepository: repository,
          spotAccountChangeRepository: spot,
          accountChangeRepository: perp,
          spotNotificationUnitsRepository: units,
        );
        await launch(tester, container);
        expect(container.read(unreadNotificationsProvider), 2);
        expect(tester.takeException(), null);
        await tester.tap(find.byKey(const Key('notifications-entry')));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
        final card = find.byKey(ValueKey('notification-${record.key}'));
        await show(tester, card, 'notification-list');
        expect(find.text(l10n.spotNotificationOrderTitle(event.status)), findsOneWidget);
        await tester.tap(card.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(SpotNotificationDetails), findsOneWidget);
        expect(find.text(l10n.openOrdersLongSide), findsNothing);
        expect(find.text(l10n.openOrdersShortSide), findsNothing);
        expect(find.text(l10n.openOrdersOneWay), findsNothing);
        expect(find.text(l10n.notificationRealizedPnl), findsNothing);
        expect(find.text(l10n.openOrdersReduceOnly), findsNothing);
        await show(tester, find.text(l10n.spotNotificationLastQuote), 'notification-details');
        expect(find.text('0.000000000000000001 SPOT_USDT'), findsOneWidget);
        expect(find.text('0.200000000000000001 SPOT_USDT'), findsOneWidget);
        expect(find.text('0.1 SPOT_BTC'), findsNWidgets(2));
        expect(find.text('0.000000000000000001 BNB'), findsOneWidget);
        expect(find.text(event.orderId), findsOneWidget);
        expect(find.text(l10n.openOrdersCreationUnknown), findsOneWidget);
        expect(find.text('1970-01-01T00:00:00.000Z'), findsNothing);
        expect(container.read(unreadNotificationsProvider), 1);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        identity.events.add(identityWithWallet);
        await tester.pumpAndSettle();
        expect(find.text(event.orderId), findsNothing);
        expect(find.byType(SpotNotificationDetails), findsNothing);
        identity.events.add(signingIdentity);
        await tester.pumpAndSettle();
        expect(find.byType(SpotNotificationDetails), findsOneWidget);
        Navigator.of(tester.element(find.byType(NotificationDetails))).pop();
        await tester.pumpAndSettle();
        await show(tester, card, 'notification-list');
        expect(find.byKey(const Key('notification-unread-dot')), findsOneWidget);
        expect(units.calls, 1);
        expect(spot.authorizations, 0);
        expect(perp.authorizations, 0);
        expect(identity.wallets, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  testWidgets('Spot and futures monitors authorize/stop independently and retain local events', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final spot = TestAccountChangeRepository(), perp = TestAccountChangeRepository();
    addTearDown(identity.dispose);
    addTearDown(spot.dispose);
    addTearDown(perp.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      accountChangeRepository: perp,
      spotAccountChangeRepository: spot,
      monitorClock: () => spot.now,
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('notifications-entry')));
    await tester.pumpAndSettle();
    await container.read(spotAccountChangeProvider.notifier).authorize();
    await tester.pumpAndSettle();
    expect(spot.authorizations, 1);
    expect(perp.authorizations, 0);
    spot.channels.last.add(const AccountChangeEvent.connected());
    final event = spotNotification();
    spot.channels.last.add(
      AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
    );
    await tester.pumpAndSettle();
    expect(container.read(walletNotificationsProvider).length, 1);
    await container.read(accountChangeProvider.notifier).authorize();
    await tester.pumpAndSettle();
    perp.channels.last.add(const AccountChangeEvent.connected());
    await tester.pumpAndSettle();
    container.read(spotAccountChangeProvider.notifier).stop();
    await tester.pumpAndSettle();
    expect(container.read(spotAccountChangeProvider).connection, AccountChangeConnection.stopped);
    expect(container.read(accountChangeProvider).connection, AccountChangeConnection.connected);
    expect(container.read(walletNotificationsProvider).length, 1);
    expect(spot.authorizations, 1);
    expect(perp.authorizations, 1);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('Spot metadata failure retries its own market without private authorization', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = LocalNotificationRepository(MemoryNotificationStorage());
    final units = TestSpotNotificationUnitsRepository()..fail = true;
    addTearDown(identity.dispose);
    addTearDown(repository.dispose);
    await repository.reload();
    await repository.add(accountAddress, spotNotification());
    final container = setup(
      tester,
      identityRepository: identity,
      notificationRepository: repository,
      spotNotificationUnitsRepository: units,
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('notifications-entry')));
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('notification-${repository.snapshot.entries.single.key}'));
    await show(tester, card, 'notification-list');
    await tester.tap(card.hitTestable());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(NotificationDetails)));
    expect(find.text(l10n.notificationUnitFailure), findsOneWidget);
    final retry = find.byKey(const Key('spot-notification-units-retry'));
    await show(tester, retry, 'notification-details');
    units.fail = false;
    await tester.tap(retry.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('0.1 SPOT_BTC'), findsNWidgets(2));
    expect(find.text(l10n.notificationUnitFailure), findsNothing);
    expect(units.calls, 2);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

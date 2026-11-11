import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/presentation/notification_details.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> show(WidgetTester tester, Finder target, String listKey) async {
    final scroll = find
        .descendant(of: find.byKey(Key(listKey)), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(target, 200, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'zh']) {
    testWidgets(
      'inbox/last and cumulative fills, read state and wallet isolation at 320/large/landscape $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final changes = TestAccountChangeRepository();
        final repository = LocalNotificationRepository(MemoryNotificationStorage());
        addTearDown(identity.dispose);
        addTearDown(changes.dispose);
        addTearDown(repository.dispose);
        await repository.reload();
        final event = notificationOrder(
          filled: '0.200000000000000001',
          last: '0.000000000000000001',
        );
        await repository.add(accountAddress, event);
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          notificationRepository: repository,
          accountChangeRepository: changes,
          monitorClock: () => changes.now,
        );
        await launch(tester, container);
        expect(tester.takeException(), null);
        expect(changes.authorizations, 0);
        await tester.tap(find.byKey(const Key('notifications-entry')));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
        final card = find.byKey(ValueKey('notification-${repository.snapshot.entries.single.key}'));
        await show(tester, card, 'notification-list');
        expect(find.byKey(const Key('notification-unread-dot')), findsOneWidget);
        await tester.tap(card.hitTestable());
        await tester.pumpAndSettle();
        expect(container.read(unreadNotificationsProvider), 0);
        expect(find.byType(NotificationDetails), findsOneWidget);
        await show(tester, find.text(l10n.notificationLastQuantity), 'notification-details');
        expect(find.text('0.000000000000000001 BTC'), findsOneWidget);
        expect(find.text('0.200000000000000001 BTC'), findsOneWidget);
        expect(find.text(event.orderId), findsOneWidget);
        expect(
          find.descendant(of: find.byType(SelectableText), matching: find.text(event.orderId)),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(identity.wallets, 0);
        identity.events.add(identityWithWallet);
        await tester.pumpAndSettle();
        expect(find.text(event.orderId), findsNothing);
        expect(find.text(l10n.notificationEmpty), findsOneWidget);
        identity.events.add(signingIdentity);
        await tester.pumpAndSettle();
        expect(find.byType(NotificationDetails), findsOneWidget);
        Navigator.of(tester.element(find.byType(NotificationDetails))).pop();
        await tester.pumpAndSettle();
        await show(tester, card, 'notification-list');
        expect(find.byKey(const Key('notification-unread-dot')), findsNothing);
        expect(changes.authorizations, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
    testWidgets('risk details list all margin positions, ADL status and scope $language', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final changes = TestAccountChangeRepository();
      final repository = LocalNotificationRepository(MemoryNotificationStorage());
      addTearDown(identity.dispose);
      addTearDown(changes.dispose);
      addTearDown(repository.dispose);
      await repository.reload();
      await repository.add(accountAddress, marginNotification());
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(language),
        identityRepository: identity,
        notificationRepository: repository,
        accountChangeRepository: changes,
      );
      await launch(tester, container);
      await tester.tap(find.byKey(const Key('notifications-entry')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
      final card = find.byKey(ValueKey('notification-${repository.snapshot.entries.single.key}'));
      await show(tester, card, 'notification-list');
      await tester.tap(card.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l10n.notificationMarginScope), findsOneWidget);
      await show(tester, find.text('ETHUSDT'), 'notification-details');
      expect(find.text('1.327 ETH'), findsOneWidget);
      await show(tester, find.text('BTCUSDT'), 'notification-details');
      expect(find.text('-0.001 BTC'), findsOneWidget);
      expect(find.text('-0.2 USDT'), findsOneWidget);
      expect(tester.takeException(), null);
      // A later ADL event must show the actual partial status, never a whole-position claim.
      final source = notificationOrder();
      final adl = OrderNotification(
        eventTime: source.eventTime,
        transactionTime: source.transactionTime,
        tradeTime: source.tradeTime,
        symbol: source.symbol,
        orderId: '7788',
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
      await repository.add(accountAddress, adl);
      Navigator.of(tester.element(find.byType(NotificationDetails))).pop();
      await tester.pumpAndSettle();
      final adlEntry = repository.snapshot.entries.firstWhere((e) => e.event is OrderNotification);
      final adlCard = find.byKey(ValueKey('notification-${adlEntry.key}'));
      await show(tester, adlCard, 'notification-list');
      await tester.tap(adlCard.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l10n.notificationAdlTitle), findsOneWidget);
      expect(find.text(l10n.notificationRiskScope), findsOneWidget);
      expect(find.text(l10n.notificationStatus('PARTIALLY_FILLED')), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets(
    'storage error is recoverable, no raw error or automatic signature; read-all stays local',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final changes = TestAccountChangeRepository();
      final storage = MemoryNotificationStorage()..failRead = true;
      final repository = LocalNotificationRepository(storage);
      addTearDown(identity.dispose);
      addTearDown(changes.dispose);
      addTearDown(repository.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        notificationRepository: repository,
        accountChangeRepository: changes,
      );
      await launch(tester, container);
      await tester.tap(find.byKey(const Key('notifications-entry')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
      final retry = find.byKey(const Key('notification-retry'));
      await show(tester, retry, 'notification-list');
      expect(find.text(l10n.notificationStorageFailed), findsOneWidget);
      expect(find.textContaining('sensitive'), findsNothing);
      storage.failRead = false;
      await tester.tap(retry.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(l10n.notificationStorageFailed), findsNothing);
      expect(find.text(l10n.notificationEmpty), findsOneWidget);
      await repository.add(accountAddress, notificationOrder());
      await tester.pumpAndSettle();
      final readAll = find.byKey(const Key('notification-read-all'));
      await show(tester, readAll, 'notification-list');
      await tester.tap(readAll.hitTestable());
      await tester.pumpAndSettle();
      expect(container.read(unreadNotificationsProvider), 0);
      expect(changes.authorizations, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('explicitly authorized monitoring feeds the inbox; logout hides cached events', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final changes = TestAccountChangeRepository();
    addTearDown(identity.dispose);
    addTearDown(changes.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      accountChangeRepository: changes,
      monitorClock: () => changes.now,
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('notifications-entry')));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
    expect(changes.authorizations, 0);
    await container.read(accountChangeProvider.notifier).authorize();
    await tester.pumpAndSettle();
    expect(changes.authorizations, 1);
    final event = notificationOrder();
    changes.channels.last.add(const AccountChangeEvent.connected());
    changes.channels.last.add(
      AccountChangeEvent.changed(AccountChangeKind.order, event.eventTime, notification: event),
    );
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationsProvider), 1);
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(walletNotificationsProvider), isEmpty);
    final signIn = find.text(l10n.notificationSignIn);
    await show(tester, signIn, 'notification-list');
    expect(signIn, findsOneWidget);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('public units failure preserves precise values and retries without private signing', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final changes = TestAccountChangeRepository();
    final repository = LocalNotificationRepository(MemoryNotificationStorage());
    final units = TestNotificationUnitsRepository()..fail = true;
    addTearDown(identity.dispose);
    addTearDown(changes.dispose);
    addTearDown(repository.dispose);
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    final container = setup(
      tester,
      identityRepository: identity,
      notificationRepository: repository,
      notificationUnitsRepository: units,
      accountChangeRepository: changes,
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
    expect(find.text('0.1 ${l10n.accountUnitUnavailable}'), findsNWidgets(2));
    final retry = find.byKey(const Key('notification-units-retry'));
    await show(tester, retry, 'notification-details');
    units.fail = false;
    await tester.tap(retry.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text(l10n.notificationUnitFailure), findsNothing);
    expect(find.text('0.1 BTC'), findsNWidgets(2));
    expect(units.calls, 2);
    expect(changes.authorizations, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

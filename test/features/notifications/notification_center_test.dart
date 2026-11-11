import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/features/notifications/domain/notification_status.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/trade_fixture.dart';
import '../../support/transfers.dart';
import '../../support/trading_agents.dart';

Future<TradingAgentStore> activeStore() async {
  final store = MemoryTradingAgentStorage().store(DateTime.now);
  final agent = await store.prepare(
    signingIdentity.id,
    accountAddress,
    DateTime.now().add(const Duration(days: 30)),
  );
  await store.setStatus(agent, TradingAgentStatus.unknown);
  await store.setStatus(agent, TradingAgentStatus.active);
  return store;
}

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
    expect(notificationStatusIcon(notificationOrder()), NotificationStatusIcon.success);
    expect(notificationStatusIcon(spotNotification()), NotificationStatusIcon.success);
    expect(notificationStatusIcon(marginNotification()), NotificationStatusIcon.warning);
    expect(notificationStatusIcon(adl), NotificationStatusIcon.info);
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

  for (final language in ['en', 'zh']) {
    testWidgets(
      'inbox tabs, unread filter, design rows and pull-to-refresh at 320/1.5x: $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = LocalNotificationRepository(MemoryNotificationStorage());
        final history = TestTransferHistoryRepository()..records = [transferRecord()];
        addTearDown(identity.dispose);
        addTearDown(repository.dispose);
        await repository.reload();
        await repository.observeTransfers(accountAddress, [], observedAt, isCurrent: () => true);
        await repository.observeTransfers(
          accountAddress,
          [transferRecord()],
          observedAt,
          isCurrent: () => true,
        );
        final perp = notificationOrder();
        await repository.add(accountAddress, perp);
        await repository.add(accountAddress, spotNotification());
        await repository.add(accountAddress, marginNotification());
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          notificationRepository: repository,
          transferHistoryRepository: history,
        );
        await launch(tester, container);
        await tester.tap(find.byKey(const Key('notifications-entry')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        // Tall enough that the lazy list builds every row.
        tester.view.physicalSize = const Size(320, 2400);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
        Finder tiles() => find.descendant(
          of: find.byKey(const Key('notification-list')),
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('notification-['),
          ),
        );
        expect(find.text('4'), findsOneWidget);
        expect(find.text(l10n.notificationToday), findsOneWidget);
        expect(find.byKey(const Key('notification-icon-pending')), findsOneWidget);
        expect(
          find.text(
            l10n.notificationTransferSummary(
              'deposit_processing',
              '0.000000000000000001 USDT',
              l10n.notificationPerp,
              l10n.transferNetworkBnb,
            ),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(find.byKey(const Key('notification-filter-transfers')));
        await tester.tap(find.byKey(const Key('notification-filter-transfers')));
        await tester.pumpAndSettle();
        expect(tiles(), findsOneWidget);
        expect(find.text(l10n.assetHistoryStatus('processing')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('notification-filter-orders')));
        await tester.tap(find.byKey(const Key('notification-filter-orders')));
        await tester.pumpAndSettle();
        expect(tiles(), findsNWidgets(2));
        expect(find.byKey(const Key('notification-icon-warning')), findsNothing);

        await tester.ensureVisible(find.byKey(const Key('notification-filter-all')));
        await tester.tap(find.byKey(const Key('notification-filter-all')));
        await repository.markRead(
          accountAddress,
          key: InboxEntry(address: accountAddress, event: perp).key,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('notification-unread-only')));
        await tester.pumpAndSettle();
        expect(tiles(), findsNWidgets(3));
        expect(find.text('3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('notification-unread-only')));
        await tester.pumpAndSettle();

        // Pull-to-refresh refreshes the deposit status in place instead of adding a row.
        history.records = [transferRecord(status: 'SUCCESS')];
        await tester.drag(find.byKey(const Key('notification-list')), const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(history.calls, 1);
        final transfers = container
            .read(walletNotificationsProvider)
            .where((e) => e.event is TransferNotification);
        expect(
          (transfers.single.event as TransferNotification).record.status,
          TransferStatus.success,
        );
        expect(find.text(l10n.assetHistoryStatus('success')), findsOneWidget);
        // A successful deposit switches to the design's success icon.
        await tester.ensureVisible(find.byKey(const Key('notification-filter-transfers')));
        await tester.tap(find.byKey(const Key('notification-filter-transfers')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('notification-icon-success')), findsOneWidget);
        expect(find.byKey(const Key('notification-icon-pending')), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('notification-filter-all')));
        await tester.tap(find.byKey(const Key('notification-filter-all')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('notification-read-all')));
        await tester.pumpAndSettle();
        expect(container.read(unreadNotificationsProvider), 0);
        expect(find.byKey(const Key('notification-read-all')), findsNothing);
        expect(find.byKey(const Key('notification-unread-dot')), findsNothing);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(identity.wallets, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }

  testWidgets('mark-all action stays on the 16 px content edge', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = LocalNotificationRepository(MemoryNotificationStorage());
    addTearDown(identity.dispose);
    addTearDown(repository.dispose);
    await repository.reload();
    await repository.add(accountAddress, notificationOrder());
    final container = setup(
      tester,
      identityRepository: identity,
      notificationRepository: repository,
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('notifications-entry')));
    await tester.pumpAndSettle();
    // Unused header flex space must sit left of the action, not after it.
    final readAll = find.byKey(const Key('notification-read-all'));
    expect(tester.getTopRight(readAll).dx, 390 - 4);
    expect(
      tester.getTopRight(find.descendant(of: readAll, matching: find.byType(Text))).dx,
      390 - 16,
    );
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('a balance update re-reads transfer status with an active grant', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = LocalNotificationRepository(MemoryNotificationStorage());
    final history = TestTransferHistoryRepository()..now = DateTime.now().toUtc();
    addTearDown(identity.dispose);
    addTearDown(repository.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      notificationRepository: repository,
      transferHistoryRepository: history,
      tradingAgentStore: await activeStore(),
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('notifications-entry')));
    await tester.pumpAndSettle();
    final before = history.calls;
    expect(before, greaterThan(0));
    container.read(transferHistoryProvider.notifier).markRefreshNeeded();
    await tester.pumpAndSettle();
    expect(history.calls, before + 1);
    expect(container.read(transferHistoryProvider).stale, false);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
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

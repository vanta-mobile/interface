import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/presentation/notification_details.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/trade_fixture.dart';
import '../../support/transfers.dart';

Future<void> show(WidgetTester tester, Finder finder, String listKey, {double delta = 180}) async {
  final scroll = find
      .descendant(of: find.byKey(Key(listKey)), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(finder, delta, scrollable: scroll);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets(
      'transfer notification has observed/record times, copyable IDs, no order units and wallet isolation: $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = LocalNotificationRepository(MemoryNotificationStorage());
        final units = TestNotificationUnitsRepository();
        final spotUnits = TestSpotNotificationUnitsRepository();
        addTearDown(identity.dispose);
        addTearDown(repository.dispose);
        await repository.reload();
        final time = DateTime.utc(2026, 11, 3);
        await repository.observeTransfers(
          accountAddress,
          [transferRecord()],
          time,
          isCurrent: () => true,
        );
        await repository.observeTransfers(
          accountAddress,
          [transferRecord(status: 'SUCCESS', hash: '0xabcdef')],
          time,
          isCurrent: () => true,
        );
        final entry = repository.snapshot.entries.single;
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          notificationRepository: repository,
          notificationUnitsRepository: units,
          spotNotificationUnitsRepository: spotUnits,
        );
        await launch(tester, container);
        await tester.tap(find.byKey(const Key('notifications-entry')));
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('notification-${entry.key}'));
        await show(tester, card, 'notification-list');
        await tester.tap(card.hitTestable());
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(NotificationDetails)));
        expect(find.text(l10n.notificationTransferTitle('deposit', 'success')), findsOneWidget);
        expect(find.text(l10n.transferObservedTime), findsOneWidget);
        expect(find.text(l10n.notificationUnits), findsNothing);
        expect(find.text(l10n.openOrdersLongSide), findsNothing);
        expect(find.text(l10n.notificationRealizedPnl), findsNothing);
        await show(tester, find.text(l10n.transferHash), 'notification-details');
        expect(find.text('0xabcdef'), findsOneWidget);
        expect(find.text(l10n.transferRecordTime), findsOneWidget);
        expect(find.text('2025-03-17T08:00:00.000Z'), findsOneWidget);
        expect(find.widgetWithText(SelectableText, '0xabcdef'), findsOneWidget);
        expect(find.widgetWithText(SelectableText, '1234567'), findsOneWidget);
        expect(container.read(unreadNotificationsProvider), 0);
        expect(spotUnits.calls, 0);
        expect(units.calls, 0);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.text('0xabcdef'), findsNothing);
        expect(find.text('1234567'), findsNothing);
        expect(find.byType(NotificationDetails), findsOneWidget);
        expect(identity.wallets, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/presentation/api_notification_details.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('API inbox tabs, unread filter and refresh at narrow enlarged text: $language', (
      tester,
    ) async {
      final f = InboxFixture();
      addTearDown(f.dispose);
      f.items.addAll([
        inboxItem(),
        inboxItem(id: 2, type: 'TRANSFER'),
        inboxItem(id: 3, type: 'ANNOUNCE', broadcast: true, read: true),
      ]);
      await f.mount(tester, language: language, size: const Size(320, 740), scale: 1.5);
      final l = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
      expect(find.text(l.notificationApiType('fill')), findsOneWidget);
      expect(find.byKey(const Key('notification-unread-dot')), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('notification-filter-transfers')));
      await tester.pumpAndSettle();
      expect(f.backend.requests.last.url.queryParameters['category'], 'transfers');
      expect(find.byKey(const Key('notification-event:1')), findsNothing);
      expect(f.state.unread, 2);
      await tester.tap(find.byKey(const Key('notification-unread-only')));
      await tester.pumpAndSettle();
      expect(f.backend.requests.last.url.queryParameters['unread_only'], 'true');
      final before = f.backend.requests.length;
      await tester.drag(find.byKey(const Key('notification-list')), const Offset(0, 360));
      await tester.pumpAndSettle();
      expect(f.backend.requests.length, greaterThan(before));
      expect(f.signer.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('mark all disables and spins through the write and count reconciliation', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    f.extraUnread = 30;
    await f.mount(tester);
    f.writeGate = Completer<void>();
    final action = find.byKey(const Key('notification-read-all'));
    await tester.tap(action);
    await tester.pump();
    expect(tester.widget<TextButton>(action).onPressed, isNull);
    expect(
      find.descendant(of: action, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    f.listGate = Completer<void>();
    f.writeGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.state.marking, isTrue);
    f.listGate!.complete();
    await tester.pumpAndSettle();
    expect(f.state.unread, 0);
    expect(action, findsNothing);
    expect(f.signer.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed read marker retains unread and displays the safe backend message', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.mount(tester);
    f.writeFailure = true;
    await tester.tap(find.byKey(const Key('notification-event:1')));
    await tester.pumpAndSettle();
    expect(find.byType(ApiNotificationDetails), findsOneWidget);
    expect(find.text('Read marker unavailable'), findsOneWidget);
    expect(f.state.unread, 1);
    f.writeFailure = false;
    final retry = find.byKey(const Key('status-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(f.state.unread, 0);
    expect(find.text('Read marker unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('entry and pull refresh never request a wallet signature implicitly', (tester) async {
    final f = InboxFixture(storedSession: false);
    addTearDown(f.dispose);
    await f.mount(tester);
    expect(find.byKey(const Key('notification-api-sign-in')), findsOneWidget);
    expect(f.signer.calls, 0);
    await tester.drag(find.byKey(const Key('notification-list')), const Offset(0, 360));
    await tester.pumpAndSettle();
    expect(f.signer.calls, 0);
    await tester.ensureVisible(find.byKey(const Key('notification-api-sign-in')));
    await tester.tap(find.byKey(const Key('notification-api-sign-in')));
    await tester.pumpAndSettle();
    expect(f.signer.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

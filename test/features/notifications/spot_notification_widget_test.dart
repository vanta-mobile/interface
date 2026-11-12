import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('API market is explicit and never inferred from the symbol: $language', (
      tester,
    ) async {
      final f = InboxFixture();
      addTearDown(f.dispose);
      f.items.addAll([
        inboxItem(payload: {'market': 'spot', 'status': 'FILLED'}),
        inboxItem(id: 2),
      ]);
      await f.mount(tester, language: language);
      final l = AppLocalizations.of(tester.element(find.byType(NotificationScreen)));
      expect(find.text(l.spot), findsOneWidget);
      expect(find.text(l.notificationPerp), findsNothing);
      expect(find.text(l.notificationStatus('FILLED')), findsOneWidget);
      await tester.tap(find.byKey(const Key('notification-event:1')));
      await tester.pumpAndSettle();
      expect(find.text(l.spot), findsOneWidget);
      expect(f.state.unread, 1);
      expect(f.signer.calls, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('broadcast details use the broadcast read cursor', (tester) async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.addAll([
      inboxItem(),
      inboxItem(
        id: 2,
        type: 'ANNOUNCE',
        broadcast: true,
        payload: {'title': 'Scheduled announcement', 'message': 'Service update.'},
      ),
      inboxItem(id: 3, type: 'MAINTENANCE', broadcast: true),
    ]);
    await f.mount(tester);
    await tester.tap(find.byKey(const Key('notification-broadcast:3')));
    await tester.pumpAndSettle();
    expect(f.state.unread, 1);
    expect(f.state.cache['broadcast:2']!.read, isTrue);
    expect(f.state.cache['event:1']!.read, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/presentation/api_notification_details.dart';
import 'package:vanta/features/notifications/presentation/notification_detail_components.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';
import '../../support/vanta_api.dart';

void main() {
  testWidgets('the detail route itself marks read and survives removal from an unread-only list', (
    tester,
  ) async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.addAll([
      inboxItem(
        payload: {
          'qty': '0.000000000000000001',
          'base_asset': 'BTC',
          'price': '12345.1234567890123456789',
          'quote_asset': 'USDT',
          'order_id': '1234567890123456789',
        },
      ),
      inboxItem(id: 2),
    ]);
    await f.mount(tester);
    await tester.tap(find.byKey(const Key('notification-unread-only')));
    await tester.pumpAndSettle();
    final entry = f.state.cache['event:1']!;
    Navigator.of(tester.element(find.byType(NotificationScreen))).push<void>(
      MaterialPageRoute(
        builder: (_) => ApiNotificationDetails(
          initialEntry: entry,
          ownerAddress: vantaTestAddress.toLowerCase(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(ApiNotificationDetails)));
    expect(find.byType(NotificationDetailSummary), findsOneWidget);
    expect(f.state.unread, 1);
    expect(f.state.items.map((e) => e.key), ['event:2']);
    expect(find.text('0.000000000000000001 BTC'), findsOneWidget);
    expect(find.text('12,345.1234567890123456789 USDT'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final copy = find.byKey(ValueKey('notification-copy-${l.notificationApiField('orderId')}'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    expect(copied, '1234567890123456789');
    expect(f.signer.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  for (final language in ['en', 'zh']) {
    testWidgets(
      'sparse risk facts fit phones, landscape and tablets without invented amounts: $language',
      (tester) async {
        final f = InboxFixture();
        addTearDown(f.dispose);
        f.items.add(
          inboxItem(
            type: 'MARGIN_CALL',
            payload: {
              'mark_price': '70000.00000001',
              'liquidation_price': '60000',
              'distance': '0.15',
            },
          ),
        );
        await f.mount(tester, language: language, size: const Size(320, 740), scale: 1.5);
        await tester.tap(find.byKey(const Key('notification-event:1')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ApiNotificationDetails)));
        expect(find.text('0.15'), findsOneWidget);
        expect(find.text('15%'), findsNothing);
        expect(find.text(l.notificationPerp), findsNothing);
        expect(find.text(l.notificationStatus('FILLED')), findsNothing);
        for (final size in [const Size(320, 740), const Size(844, 390), const Size(1024, 768)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        f.auth.setWallet('0x${'ab' * 20}');
        await tester.pumpAndSettle();
        expect(find.text('0.15'), findsNothing);
        expect(find.text(l.notificationEmpty), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

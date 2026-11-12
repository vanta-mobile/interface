import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/presentation/api_notification_details.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets(
      'server transfer details preserve exact amount and hash with wallet isolation: $language',
      (tester) async {
        final f = InboxFixture();
        addTearDown(f.dispose);
        f.items.add(
          inboxItem(
            type: 'TRANSFER',
            symbol: null,
            payload: {
              'amount': '0.000000000000000001',
              'asset': 'ETH',
              'tx_hash': '0xabcdef',
              'status': 'success',
            },
          ),
        );
        await f.mount(tester, language: language, size: const Size(320, 740), scale: 1.5);
        await tester.tap(find.byKey(const Key('notification-event:1')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ApiNotificationDetails)));
        expect(find.text('0.000000000000000001 ETH'), findsNWidgets(2));
        final hash = find.widgetWithText(SelectableText, '0xabcdef');
        await tester.ensureVisible(hash);
        expect(hash, findsOneWidget);
        expect(
          find.byKey(ValueKey('notification-copy-${l.notificationApiField('transactionHash')}')),
          findsOneWidget,
        );
        expect(f.state.unread, 0);
        expect(f.signer.calls, 0);
        f.auth.setWallet(null);
        await tester.pumpAndSettle();
        expect(hash, findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

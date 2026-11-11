import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/presentation/attached_exit_input_controls.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets(
      'filled TP waits quietly for entry quantity but keeps actual input errors: $language',
      (tester) async {
        final entry = ValueNotifier(liveDraft(market: true, price: '', quantity: '2'));
        addTearDown(entry.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: vantaTheme(),
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<LiveOrderDraft>(
                valueListenable: entry,
                builder: (_, draft, _) => AttachedExitInputControls(
                  kind: LiveOrderTriggerKind.takeProfit,
                  compact: true,
                  enabled: true,
                  advanced: false,
                  data: capacityContext(),
                  entry: draft,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('attached-tp-price'));
        final l = AppLocalizations.of(tester.element(field));
        final dependencyIssue = l.attachedOrderExitIssue(
          l.attachedOrderTakeProfit,
          l.attachedOrderPreviewUnavailable,
        );
        await tester.enterText(field, '2');
        await tester.pump();
        expect(find.text(dependencyIssue), findsNothing);
        entry.value = entry.value.withQuantity('');
        await tester.pump();
        expect(find.text(dependencyIssue), findsNothing);
        expect(find.textContaining(l.liveOrderInvalidQuantity), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text, '2');
        await tester.enterText(field, '-2');
        await tester.pump();
        final invalid = l.attachedOrderExitIssue(
          l.attachedOrderTakeProfit,
          l.attachedOrderTargetSign,
        );
        expect(find.text(invalid), findsOneWidget);
        entry.value = entry.value.withQuantity('2');
        await tester.enterText(field, '2');
        await tester.pump();
        expect(find.text(invalid), findsNothing);
        expect(find.text(dependencyIssue), findsNothing);
        await tester.tap(find.byKey(const Key('attached-tp-mode')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.tradeExitPrice('USDT')).last);
        await tester.pumpAndSettle();
        await tester.enterText(field, '110');
        entry.value = entry.value.withQuantity('');
        await tester.pump();
        expect(find.textContaining(l.liveOrderInvalidQuantity), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text, '110');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

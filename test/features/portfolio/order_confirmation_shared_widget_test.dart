import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/order_confirmation_widget.dart';
import '../../support/quick_order.dart';
import '../../support/workspace_navigation.dart';

Future<void> quickTap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final market in [false, true]) {
    testWidgets(
      'attached protection follows explicit main ${market ? 'market' : 'limit'} opening preference',
      (tester) async {
        final prefs = MemoryOrderConfirmationPreferences()
          ..values[market ? OrderConfirmationKind.market : OrderConfirmationKind.limit] = false;
        final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
        final container = await launchConfirmation(tester, orders, prefs);
        await fillConfirmation(
          tester,
          market ? OrderConfirmationKind.market : OrderConfirmationKind.limit,
        );
        await tapConfirmation(tester, 'live-order-attached');
        await tapConfirmation(tester, 'attached-tp-enabled');
        await confirmationField(tester, 'attached-tp-price', '1');
        await tapConfirmation(tester, 'live-order-review');
        expect(find.byType(AlertDialog), findsNothing);
        expect(orders.submits, 1);
        expect(orders.lastIntent!.draft.attachment!.takeProfit, isNotNull);
        expect(orders.lastIntent!.draft.quantity, '0.001');
        expect(orders.lastIntent!.draft.attachment!.strategyType, 'OTO');
        expect(prefs.writes, 0);
        expect(tester.takeException(), null);
        await closeConfirmation(tester, container);
      },
    );
  }
  testWidgets('market choice saved in main form applies to chart; chart can restore confirmation', (
    tester,
  ) async {
    final prefs = MemoryOrderConfirmationPreferences();
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    final sizing = TestQuickOrderRepository();
    final container = await launchConfirmation(tester, orders, prefs, sizing: sizing);
    await fillConfirmation(tester, OrderConfirmationKind.market);
    await tapConfirmation(tester, 'live-order-review');
    await toggleDialogSkip(tester);
    await confirmDialog(tester);
    expect(orders.submits, 1);
    expect(prefs.required, false);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final tabs = find.byKey(const Key('trade-workspace-tabs'));
    await tester.ensureVisible(tabs);
    final l10n = AppLocalizations.of(tester.element(tabs));
    await selectWorkspace(tester, chart: true);
    await quickTap(tester, 'quick-order-read');
    final qty = find.byKey(const Key('quick-order-quantity'));
    await tester.ensureVisible(qty);
    await tester.enterText(qty, '0.001');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('quick-order-confirmation-preference')))
          .value,
      false,
    );
    await quickTap(tester, 'quick-order-buy');
    expect(find.byType(AlertDialog), findsNothing);
    expect(orders.submits, 2);
    await quickTap(tester, 'quick-order-read');
    await quickTap(tester, 'quick-order-confirmation-preference');
    expect(container.read(orderConfirmationProvider(OrderConfirmationKind.market)).required, true);
    expect(container.read(orderConfirmationProvider(OrderConfirmationKind.limit)).required, true);
    expect(prefs.required, true);
    await tester.ensureVisible(qty);
    await tester.enterText(qty, '0.001');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await quickTap(tester, 'quick-order-buy');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(orders.submits, 2);
    expect(
      tester.widget<CheckboxListTile>(find.byKey(const Key('quick-order-skip-confirmation'))).value,
      false,
    );
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
  testWidgets('disabled preference read failure restores review instead of skipping', (
    tester,
  ) async {
    final prefs = MemoryOrderConfirmationPreferences()
      ..values[OrderConfirmationKind.limit] = false
      ..failRead = true;
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    final container = await launchConfirmation(tester, orders, prefs);
    await fillConfirmation(tester, OrderConfirmationKind.limit);
    await tapConfirmation(tester, 'live-order-review');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(orders.submits, 0);
    expect(container.read(orderConfirmationProvider(OrderConfirmationKind.limit)).failure, true);
    await cancelConfirmation(tester);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
}

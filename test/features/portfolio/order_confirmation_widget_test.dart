import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_confirmation_widget.dart';
import '../../support/quick_order.dart';

void main() {
  for (final language in ['en', 'zh']) {
    for (final kind in OrderConfirmationKind.values) {
      testWidgets(
        'mode $kind $language default review, cancel, opt-out, reopen and independent switch',
        (tester) async {
          final orders = TestLiveOrderRepository()
            ..context = liveContext(bid: '80000', ask: '80000');
          final prefs = MemoryOrderConfirmationPreferences();
          final container = await launchConfirmation(
            tester,
            orders,
            prefs,
            language: language,
            width: 320,
            scale: 1.5,
          );
          await fillConfirmation(tester, kind);
          await tapConfirmation(tester, 'live-order-review');
          expect(find.byType(OrderConfirmationDialog), findsOneWidget);
          expect(orders.submits, 0);
          await cancelConfirmation(tester);
          expect(prefs.writes, 0);
          expect(orders.submits, 0);
          await tapConfirmation(tester, 'live-order-review');
          await confirmDialog(tester);
          expect(orders.submits, 1);
          expect(prefs.writes, 0);
          final before = orders.lastIntent!;
          final setting = 'order-confirmation-${kind.name}';
          await tapConfirmation(tester, 'live-order-read');
          await tapConfirmation(tester, setting);
          expect(prefs.values[kind], false);
          for (final other in OrderConfirmationKind.values.where((v) => v != kind)) {
            expect(prefs.values[other], null);
          }
          await tapConfirmation(tester, 'live-order-review');
          expect(find.byType(OrderConfirmationDialog), findsNothing);
          expect(orders.submits, 2);
          expect(orders.lastIntent!.draft.orderType, before.draft.orderType);
          expect(orders.lastIntent!.draft.quantity, '0.001');
          await tapConfirmation(tester, 'live-order-read');
          await tapConfirmation(tester, setting);
          expect(prefs.values[kind], true);
          await tapConfirmation(tester, 'live-order-review');
          expect(find.byType(OrderConfirmationDialog), findsOneWidget);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          container.read(localeProvider.notifier).select(language == 'en' ? 'zh' : 'en');
          await tester.pumpAndSettle();
          expect(find.byType(OrderConfirmationDialog), findsOneWidget);
          expect(orders.submits, 2);
          await cancelConfirmation(tester);
          await closeConfirmation(tester, container);
        },
      );
    }
  }
  testWidgets('limit preference is shared with Post Only while conditional modes stay enabled', (
    tester,
  ) async {
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    final prefs = MemoryOrderConfirmationPreferences();
    final container = await launchConfirmation(tester, orders, prefs);
    await fillConfirmation(tester, OrderConfirmationKind.limit);
    final policy = find.byKey(const Key('live-order-policy'));
    await revealConfirmation(tester, policy);
    await tester.tap(policy);
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(policy));
    await tester.tap(find.text(l10n.liveOrderPolicyPostOnly).last);
    await tester.pumpAndSettle();
    await tapConfirmation(tester, 'order-confirmation-limit');
    await tapConfirmation(tester, 'live-order-review');
    expect(find.byType(OrderConfirmationDialog), findsNothing);
    expect(orders.submits, 1);
    expect(orders.lastIntent!.draft.timeInForce, LiveOrderTimeInForce.postOnly);
    expect(orders.lastIntent!.parameters['timeInForce'], 'GTX');
    await tapConfirmation(tester, 'live-order-read');
    await tapConfirmation(tester, 'live-order-conditional');
    await confirmationField(tester, 'live-order-trigger-price', '81000');
    expect(
      container.read(orderConfirmationProvider(OrderConfirmationKind.stopLimit)).required,
      true,
    );
    await tapConfirmation(tester, 'live-order-review');
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    expect(orders.submits, 1);
    await cancelConfirmation(tester);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
  testWidgets('opening opt-out does not bypass dedicated position close review', (tester) async {
    final orders = TestLiveOrderRepository()
      ..context = liveContext(
        positions: {
          'BOTH': LiveOrderPosition(
            side: 'BOTH',
            quantity: Decimal.parse('0.005'),
            entryPrice: Decimal.parse('79000'),
          ),
        },
        bid: '80000',
        ask: '80000',
      );
    final prefs = MemoryOrderConfirmationPreferences()..required = false;
    final container = await launchConfirmation(tester, orders, prefs, closing: true);
    await confirmationField(tester, 'live-order-quantity', '0.001');
    await tapConfirmation(tester, 'live-order-review');
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    expect(find.byKey(const Key('order-confirmation-market')), findsNothing);
    expect(orders.submits, 0);
    await cancelConfirmation(tester);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
  testWidgets('identity change while dialog open prevents saving or submitting old confirmation', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    final prefs = MemoryOrderConfirmationPreferences();
    final container = await launchConfirmation(tester, orders, prefs, identity: identity);
    await fillConfirmation(tester, OrderConfirmationKind.limit);
    await tapConfirmation(tester, 'live-order-review');
    identity.events.add(null);
    await tester.pumpAndSettle();
    await confirmDialog(tester);
    expect(orders.submits, 0);
    expect(prefs.writes, 0);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
  testWidgets('unknown result keeps preferences editable and rechecks the original ID', (
    tester,
  ) async {
    final orders = TestLiveOrderRepository()
      ..context = liveContext(bid: '80000', ask: '80000')
      ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    final prefs = MemoryOrderConfirmationPreferences()..values[OrderConfirmationKind.limit] = false;
    final container = await launchConfirmation(tester, orders, prefs);
    await fillConfirmation(tester, OrderConfirmationKind.limit);
    await tapConfirmation(tester, 'live-order-review');
    expect(orders.submits, 1);
    expect(find.byType(OrderConfirmationDialog), findsNothing);
    final id = orders.lastIntent!.clientOrderId;
    final review = find.byKey(const Key('live-order-review'));
    expect(tester.widget<FilledButton>(review).onPressed, null);
    final toggle = find.byKey(const Key('order-confirmation-limit'));
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    orders.result = LiveOrderResult(
      orderId: '12345',
      status: 'FILLED',
      executedQuantity: Decimal.parse('0.001'),
    );
    await tapConfirmation(tester, 'live-order-recheck');
    expect(orders.submits, 1);
    expect(orders.checks, 1);
    expect(orders.lastIntent!.clientOrderId, id);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
  testWidgets('tablet re-enable and language preserve explicit mode preference without reads', (
    tester,
  ) async {
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    final prefs = MemoryOrderConfirmationPreferences();
    final container = await launchConfirmation(
      tester,
      orders,
      prefs,
      width: 768,
      height: 1024,
      language: 'zh',
    );
    await fillConfirmation(tester, OrderConfirmationKind.trailing);
    final reads = orders.reads;
    await tapConfirmation(tester, 'order-confirmation-trailing');
    container.read(localeProvider.notifier).select('en');
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('order-confirmation-trailing'))).value,
      false,
    );
    expect(orders.reads, reads);
    expect(orders.submits, 0);
    expect(prefs.writes, 1);
    await tapConfirmation(tester, 'order-confirmation-trailing');
    expect(prefs.values[OrderConfirmationKind.trailing], true);
    expect(prefs.writes, 2);
    expect(tester.takeException(), null);
    await closeConfirmation(tester, container);
  });
}

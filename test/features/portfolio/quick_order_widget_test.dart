import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/presentation/quick_order_panel.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/quick_order.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String value) async {
    await visible(tester, 'quick-order-quantity');
    await tester.enterText(find.byKey(const Key('quick-order-quantity')), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    await selectWorkspace(tester, chart: true);
    await tester.pumpAndSettle();
    await visible(tester, 'quick-order-panel');
  }

  String quantity(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('quick-order-quantity'))).controller!.text;
  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(QuickOrderPanel)));
  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final language in ['en', 'zh']) {
    for (final hedge in [false, true]) {
      for (final buy in [false, true]) {
        testWidgets(
          'chart quick entry confirmation/unknown recovery 320 large/landscape $language $hedge $buy',
          (tester) async {
            final identity = TestIdentityRepository()..restored = signingIdentity;
            final orders = TestLiveOrderRepository()
              ..context = liveContext(
                bid: '79999',
                ask: '80001',
                mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
              )
              ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
            final sizing = TestQuickOrderRepository(),
                preference = MemoryOrderConfirmationPreferences();
            addTearDown(identity.dispose);
            final container = setup(
              tester,
              width: 320,
              scale: 1.5,
              language: Locale(language),
              identityRepository: identity,
              liveOrderRepository: orders,
              quickOrderRepository: sizing,
              orderConfirmationPreferences: preference,
              liveClock: () => liveOrderClock,
            );
            await open(tester, container);
            expect(orders.reads, 0);
            expect(sizing.reads, 0);
            expect(quantity(tester), '');
            await tap(tester, 'quick-order-read');
            await field(tester, '0.001');
            final key = buy ? 'quick-order-buy' : 'quick-order-sell';
            await tap(tester, key);
            final dialog = find.byType(AlertDialog), messages = l10n(tester);
            expect(dialog, findsOneWidget);
            expect(find.descendant(of: dialog, matching: find.text('0.001')), findsOneWidget);
            expect(
              find.descendant(of: dialog, matching: find.text(messages.quickOrderHint)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: dialog, matching: find.text(messages.liveOrderEstimatedNotional)),
              findsNothing,
            );
            expect(tester.takeException(), null);
            tester.view.physicalSize = const Size(844, 390);
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            await tester.tap(find.text(messages.cancel));
            await tester.pumpAndSettle();
            expect(orders.submits, 0);
            await tap(tester, 'quick-order-read');
            expect(quantity(tester), '0.001');
            await tap(tester, key);
            await tester.tap(find.byKey(const Key('quick-order-confirm')));
            await tester.pumpAndSettle();
            expect(orders.lastIntent!.parameters['type'], 'MARKET');
            expect(orders.lastIntent!.parameters['side'], buy ? 'BUY' : 'SELL');
            expect(
              orders.lastIntent!.parameters['positionSide'],
              hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH',
            );
            expect(orders.lastIntent!.parameters['reduceOnly'], hedge ? null : 'false');
            expect(quantity(tester), '0.001');
            await visible(tester, 'quick-order-quantity');
            expect(
              tester.widget<TextField>(find.byKey(const Key('quick-order-quantity'))).readOnly,
              true,
            );
            final id = orders.lastIntent!.clientOrderId;
            orders.result = LiveOrderResult(
              orderId: '12345',
              status: 'FILLED',
              executedQuantity: Decimal.parse('0.001'),
            );
            await tap(tester, 'live-order-recheck');
            expect(orders.submits, 1);
            expect(orders.checks, 1);
            expect(orders.lastIntent!.clientOrderId, id);
            expect(quantity(tester), '');
            expect(identity.wallets, 0);
            expect(tester.takeException(), null);
            await dispose(tester, container);
          },
        );
      }
    }
  }
  testWidgets(
    'percentages, manual replacement and explicitly disabling shared market confirmation',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final orders = TestLiveOrderRepository()..context = liveContext(bid: '79999', ask: '80001');
      final sizing = TestQuickOrderRepository(), preference = MemoryOrderConfirmationPreferences();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        liveOrderRepository: orders,
        quickOrderRepository: sizing,
        orderConfirmationPreferences: preference,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      await tap(tester, 'quick-order-read');
      await tap(tester, 'quick-order-percent-50');
      expect(quantity(tester), '');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('quick-order-percent-50'))).selected,
        true,
      );
      await field(tester, '0.001');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('quick-order-percent-50'))).selected,
        false,
      );
      await tap(tester, 'quick-order-buy');
      await tap(tester, 'quick-order-skip-confirmation');
      await tester.tap(find.text(l10n(tester).cancel));
      await tester.pumpAndSettle();
      expect(preference.required, true);
      await tap(tester, 'quick-order-buy');
      await tap(tester, 'quick-order-skip-confirmation');
      await tester.tap(find.byKey(const Key('quick-order-confirm')));
      await tester.pumpAndSettle();
      expect(preference.required, false);
      expect(orders.submits, 1);
      expect(quantity(tester), '');
      await tap(tester, 'quick-order-read');
      await field(tester, '0.001');
      await tap(tester, 'quick-order-sell');
      expect(find.byType(AlertDialog), findsNothing);
      expect(orders.submits, 2);
      expect(tester.takeException(), null);
      await dispose(tester, container);
    },
  );
  testWidgets('percentage read failure preserves manual input with retry; no demo balance used', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestLiveOrderRepository()..context = liveContext(bid: '79999', ask: '80001');
    final sizing = TestQuickOrderRepository()..failure = const AccountReadFailure('accountNetwork');
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: orders,
      quickOrderRepository: sizing,
      orderConfirmationPreferences: MemoryOrderConfirmationPreferences(),
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await field(tester, '0.001');
    await tap(tester, 'quick-order-read');
    expect(quantity(tester), '0.001');
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('quick-order-percent-50'))).onSelected,
      null,
    );
    await visible(tester, 'quick-order-buy');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('quick-order-buy'))).onPressed,
      isNotNull,
    );
    sizing.failure = null;
    await tap(tester, 'quick-order-read');
    await tap(tester, 'quick-order-percent-25');
    await tap(tester, 'quick-order-buy');
    await tester.tap(find.byKey(const Key('quick-order-confirm')));
    await tester.pumpAndSettle();
    expect(orders.lastIntent!.draft.quantity, '0.002');
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
  testWidgets('chart and trade tabs preserve separate quantity and price inputs', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: TestLiveOrderRepository(),
      quickOrderRepository: TestQuickOrderRepository(),
      orderConfirmationPreferences: MemoryOrderConfirmationPreferences(),
    );
    await launch(tester, container);
    await selectWorkspace(tester, chart: false);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await tester.pumpAndSettle();
    final priceField = find.byKey(const Key('live-order-price'));
    final sizeField = find.byKey(const Key('live-order-quantity'));
    final fields = [priceField, sizeField];
    await tester.ensureVisible(fields.first);
    await tester.enterText(fields.first, '79000');
    await tester.ensureVisible(fields.last);
    await tester.enterText(fields.last, '0.2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final tabs = find.byKey(const Key('trade-workspace-tabs'));
    await tester.ensureVisible(tabs);
    await selectWorkspace(tester, chart: true);
    expect(quantity(tester), '');
    await field(tester, '0.001');
    await tester.ensureVisible(tabs);
    await selectWorkspace(tester, chart: false);
    expect(tester.widget<TextField>(fields.first).controller!.text, '79000');
    expect(tester.widget<TextField>(fields.last).controller!.text, '0.2');
    await tester.ensureVisible(tabs);
    await selectWorkspace(tester, chart: true);
    expect(quantity(tester), '0.001');
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
}

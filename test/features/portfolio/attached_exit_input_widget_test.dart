import '../../support/order_confirmation_widget.dart';
import '../../support/order_mode_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_exit_input.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/trade_fixture.dart';

import '../../support/live_order_widget.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 180, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(find.byKey(Key(key))), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (await toggleOrderMode(tester, key)) return;
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    if (key == 'live-order-quantity') await selectLiveBase(tester);
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String text) async {
    await tap(tester, key);
    final item = find.text(text).last;
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLiveOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
    await field(tester, 'live-order-quantity', '0.002');
    await field(tester, 'live-order-price', '80000');
    await tap(tester, 'live-order-attached');
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final locale in ['en', 'zh']) {
    testWidgets('default PnL / Mark, independent limits, review and failure retention $locale', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final repository = TestLiveOrderRepository()
        ..context = liveContext(bid: '80000', ask: '80000')
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(locale),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      await tap(tester, 'attached-tp-enabled');
      expect(
        tester
            .widget<DropdownButtonFormField<AttachedExitInputMode>>(
              find.byKey(const Key('attached-tp-mode')),
            )
            .initialValue,
        AttachedExitInputMode.pnl,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<LiveOrderTriggerBasis>>(
              find.byKey(const Key('attached-tp-basis')),
            )
            .initialValue,
        LiveOrderTriggerBasis.mark,
      );
      await field(tester, 'attached-tp-price', '+2');
      await tap(tester, 'attached-sl-enabled');
      await field(tester, 'attached-sl-price', '-1');
      await tap(tester, 'attached-advanced');
      final l10n = messages(tester);
      await choose(tester, 'attached-sl-execution', l10n.attachedOrderManualLimit);
      await field(tester, 'attached-sl-limit', '79400');
      await choose(tester, 'attached-tp-execution', l10n.attachedOrderAutomaticLimit);
      await tap(tester, 'live-order-review');
      final dialog = find.byType(OrderConfirmationDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byKey(const Key('order-confirm-quantity'))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('≥ 81000 USDT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('≤ 79500 USDT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('79400 USDT')),
        findsOneWidget,
      );
      expect(repository.submits, 0);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await field(tester, 'live-order-quantity', '0.004');
      await tap(tester, 'live-order-review');
      expect(
        find.descendant(of: dialog, matching: find.textContaining('≥ 80500 USDT')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('≤ 79750 USDT')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('live-order-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      final attempted = repository.lastIntent!;
      expect(attempted.draft.quantity, '0.004');
      expect(attempted.draft.attachment!.takeProfit!.executionPrice, '80500');
      expect(attempted.draft.attachment!.stopLoss!.limitPrice, '79400');
      expect(attempted.draft.attachment!.drivenOn, AttachedOrderDrivenOn.partialOrFilled);
      await visible(tester, 'attached-sl-limit');
      final limit = tester.widget<TextField>(find.byKey(const Key('attached-sl-limit')));
      expect(limit.controller!.text, '79400');
      expect(limit.readOnly, false);
      expect(repository.submits, 1);
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }

  testWidgets(
    'mode and advanced switches retain raw inputs while only effective terms reach review',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final repository = TestLiveOrderRepository();
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      final l10n = messages(tester);
      await tap(tester, 'attached-tp-enabled');
      await field(tester, 'attached-tp-price', '2');
      await choose(tester, 'attached-tp-mode', l10n.attachedOrderRoiMode);
      await field(tester, 'attached-tp-price', '25');
      await tap(tester, 'live-order-review');
      expect(
        find.descendant(
          of: find.byType(OrderConfirmationDialog),
          matching: find.textContaining('≥ 82000 USDT'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await choose(tester, 'attached-tp-mode', l10n.attachedOrderPriceMode);
      await field(tester, 'attached-tp-price', '81500');
      await choose(tester, 'attached-tp-mode', l10n.attachedOrderPnlMode);
      expect(
        tester.widget<TextField>(find.byKey(const Key('attached-tp-price'))).controller!.text,
        '2',
      );
      await tap(tester, 'attached-advanced');
      await choose(tester, 'attached-tp-execution', l10n.attachedOrderManualLimit);
      await field(tester, 'attached-tp-limit', '80999.9');
      await tap(tester, 'attached-advanced');
      await tap(tester, 'live-order-review');
      final dialog = find.byType(OrderConfirmationDialog);
      expect(find.descendant(of: dialog, matching: find.textContaining('80999.9')), findsNothing);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await tap(tester, 'attached-advanced');
      await visible(tester, 'attached-tp-limit');
      expect(
        tester.widget<TextField>(find.byKey(const Key('attached-tp-limit'))).controller!.text,
        '80999.9',
      );
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  testWidgets('missing market quote and invalid signed targets block review without signatures', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestLiveOrderRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await tap(tester, 'attached-sl-enabled');
    await field(tester, 'attached-sl-price', '1');
    await visible(tester, 'live-order-review');
    expect(tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed, null);
    await field(tester, 'attached-sl-price', '-1');
    await chooseOrderExecution(tester, true);
    await visible(tester, 'live-order-review');
    expect(tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed, null);
    expect(repository.submits, 0);
    expect(repository.checks, 0);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
}

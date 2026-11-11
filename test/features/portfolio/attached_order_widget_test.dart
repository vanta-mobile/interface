import '../../support/order_confirmation_widget.dart';
import '../../support/order_mode_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/strategy_execution_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/quick_order.dart';
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

  String text(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLiveOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  Future<void> priceMode(WidgetTester tester, String side) async {
    await tap(tester, 'attached-$side-mode');
    final price = find
        .text(
          AppLocalizations.of(tester.element(find.byType(LiveOrderScreen))).attachedOrderPriceMode,
        )
        .last;
    await tester.ensureVisible(price);
    await tester.tap(price);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await field(tester, 'live-order-quantity', '0.001');
    if (find.byKey(const Key('live-order-price')).evaluate().isNotEmpty) {
      await field(tester, 'live-order-price', '80000');
    }
    await tap(tester, 'live-order-attached');
    await tap(tester, 'attached-tp-enabled');
    await priceMode(tester, 'tp');
    await field(tester, 'attached-tp-price', '81000');
    await tap(tester, 'attached-sl-enabled');
    await priceMode(tester, 'sl');
    await field(tester, 'attached-sl-price', '79000');
  }

  for (final language in ['zh', 'en']) {
    for (final market in [false, true]) {
      testWidgets(
        'attached TP/SL review/recovery preserves fields, narrow/large/landscape $language $market',
        (tester) async {
          final identity = TestIdentityRepository()..restored = signingIdentity;
          addTearDown(identity.dispose);
          final repository =
              (TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000'))
                ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
          final container = setup(
            tester,
            width: 320,
            scale: 1.5,
            language: Locale(language),
            identityRepository: identity,
            liveOrderRepository: repository,
            liveClock: () => liveOrderClock,
            orderConfirmationPreferences: MemoryOrderConfirmationPreferences(),
          );
          await open(tester, container);
          if (market) {
            await chooseOrderExecution(tester, true);
          }
          await fill(tester);
          await tap(tester, 'live-order-review');
          final messages = l10n(tester), dialog = find.byType(OrderConfirmationDialog);
          expect(dialog, findsOneWidget); // default opening-mode preference requires review
          expect(repository.submits, 0);
          for (final label in [messages.orderConfirmTakeProfit, messages.orderConfirmStopLoss]) {
            expect(find.descendant(of: dialog, matching: find.text(label)), findsOneWidget);
          }
          expect(
            find.descendant(of: dialog, matching: find.textContaining('≥ 81000 USDT')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dialog, matching: find.textContaining('≤ 79000 USDT')),
            findsOneWidget,
          );
          expect(tester.takeException(), null);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          await tester.tap(find.text(messages.cancel));
          await tester.pumpAndSettle();
          await tap(tester, 'live-order-read');
          await visible(tester, 'attached-tp-price');
          expect(text(tester, 'attached-tp-price'), '81000');
          await visible(tester, 'attached-sl-price');
          expect(text(tester, 'attached-sl-price'), '79000');
          await tap(tester, 'live-order-review');
          final confirm = find.byKey(const Key('live-order-confirm'));
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          await dismissOrderConfirmation(tester);
          expect(repository.submits, 1);
          final attempted = repository.lastIntent!;
          expect(attempted.draft.attachment!.takeProfit!.price, '81000');
          await visible(tester, 'attached-tp-price');
          expect(
            tester.widget<TextField>(find.byKey(const Key('attached-tp-price'))).readOnly,
            true,
          );
          expect(text(tester, 'attached-tp-price'), '81000');
          repository.result = LiveOrderResult(
            strategy: AttachedOrderSnapshot(
              strategyId: '9876',
              status: 'WORKING',
              legs: const [
                AttachedOrderLeg(sequence: 1, status: 'NEW', orderId: '100'),
                AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW'),
                AttachedOrderLeg(sequence: 3, status: 'PENDING_NEW'),
              ],
            ),
          );
          await tap(tester, 'live-order-recheck');
          expect(repository.submits, 1);
          expect(repository.checks, 1);
          expect(repository.lastIntent!.clientOrderId, attempted.clientOrderId);
          expect(find.text(messages.attachedOrderVerified), findsOneWidget);
          await tap(tester, 'attached-order-refresh');
          expect(repository.submits, 1);
          expect(repository.checks, 2);
          await tap(tester, 'attached-order-execution');
          final details = tester.widget<StrategyExecutionScreen>(
            find.byType(StrategyExecutionScreen),
          );
          expect(details.query.strategyId, '9876');
          expect(details.query.order.clientOrderId, attempted.clientOrderId);
          expect(details.query.order.protectedQuantity, attempted.draft.quantity);
          expect(repository.submits, 1);
          expect(repository.checks, 2);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
      );
    }
  }
  testWidgets('attachment toggles retain their input and trailing hides dormant protection', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = (TestLiveOrderRepository()
      ..context = liveContext(bid: '80000', ask: '80000'));
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await fill(tester);
    await tap(tester, 'live-order-attached');
    expect(find.byKey(const Key('attached-tp-price')), findsNothing);
    await tap(tester, 'live-order-attached');
    await visible(tester, 'attached-tp-price');
    expect(text(tester, 'attached-tp-price'), '81000');
    await tap(tester, 'live-order-trailing');
    expect(find.byKey(const Key('live-order-attached')), findsNothing);
    await field(tester, 'live-trailing-rate', '1');
    await tap(tester, 'live-order-review');
    final confirm = find.byKey(const Key('live-order-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await dismissOrderConfirmation(tester);
    expect(repository.lastIntent!.draft.attachment, null);
    expect(repository.lastIntent!.draft.trailing!.callbackRate, '1');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

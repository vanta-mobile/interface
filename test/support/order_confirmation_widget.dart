import 'order_mode_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'aster_account.dart';
import 'identity_repository.dart';
import 'live_order.dart';
import 'live_order_widget.dart';
import 'quick_order.dart';
import 'trade_fixture.dart';

Future<ProviderContainer> launchConfirmation(
  WidgetTester tester,
  TestLiveOrderRepository orders,
  MemoryOrderConfirmationPreferences preferences, {
  String language = 'en',
  double width = 390,
  double height = 844,
  double scale = 1,
  TestIdentityRepository? identity,
  bool closing = false,
  TestQuickOrderRepository? sizing,
}) async {
  final auth = identity ?? (TestIdentityRepository()..restored = signingIdentity);
  addTearDown(auth.dispose);
  final container = setup(
    tester,
    identityRepository: auth,
    liveOrderRepository: orders,
    quickOrderRepository: sizing,
    orderConfirmationPreferences: preferences,
    liveClock: () => liveOrderClock,
    language: Locale(language),
    width: width,
    scale: scale,
  );
  tester.view.physicalSize = Size(width, height);
  await launch(tester, container);
  final context = tester.element(find.byType(Navigator).first);
  if (closing) {
    openLiveClose(context, 'BTCUSDT', 'BOTH');
  } else {
    openLiveOrder(context, 'BTCUSDT');
  }
  await tester.pumpAndSettle();
  expect(orders.reads, 0);
  expect(orders.submits, 0);
  await tapConfirmation(tester, 'live-order-read');
  return container;
}

Future<void> revealConfirmation(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
      .first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 200, scrollable: scroll);
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> tapConfirmation(WidgetTester tester, String key) async {
  if (await toggleOrderMode(tester, key)) return;
  final target = find.byKey(Key(key));
  await revealConfirmation(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> confirmationField(WidgetTester tester, String key, String value) async {
  final field = find.byKey(Key(key));
  await revealConfirmation(tester, field);
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> confirmationMarket(WidgetTester tester, bool market) async {
  await chooseOrderExecution(tester, market);
}

Future<void> fillConfirmation(WidgetTester tester, OrderConfirmationKind kind) async {
  if (kind == OrderConfirmationKind.trailing) {
    await tapConfirmation(tester, 'live-order-trailing');
    await confirmationField(tester, 'live-trailing-rate', '1');
  } else {
    if (kind == OrderConfirmationKind.stopLimit || kind == OrderConfirmationKind.stopMarket) {
      await tapConfirmation(tester, 'live-order-conditional');
      await confirmationField(tester, 'live-order-trigger-price', '81000');
    }
    if (kind == OrderConfirmationKind.market || kind == OrderConfirmationKind.stopMarket) {
      await confirmationMarket(tester, true);
    }
  }
  await selectLiveBase(tester);
  await confirmationField(tester, 'live-order-quantity', '0.001');
  if (kind == OrderConfirmationKind.limit || kind == OrderConfirmationKind.stopLimit) {
    await confirmationField(tester, 'live-order-price', '80000');
  }
}

Future<void> toggleDialogSkip(WidgetTester tester) async {
  final skip = find.byKey(const Key('live-order-skip-confirmation'));
  await tester.ensureVisible(skip);
  await tester.pumpAndSettle();
  await tester.tap(skip);
  await tester.pumpAndSettle();
}

Future<void> confirmDialog(WidgetTester tester) async {
  final button = find.byKey(const Key('live-order-confirm'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> cancelConfirmation(WidgetTester tester) async {
  final dialog = find.byType(AlertDialog),
      l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
  await tester.tap(find.descendant(of: dialog, matching: find.text(l10n.cancel)));
  await tester.pumpAndSettle();
}

Future<void> closeConfirmation(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

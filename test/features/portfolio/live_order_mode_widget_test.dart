import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_screen.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/live_order_widget.dart';
import '../../support/order_mode_widget.dart';
import '../../support/trade_fixture.dart';

Future<void> _show(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  final scroll = find
      .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(scroll).position.jumpTo(0);
  await t.pumpAndSettle();
  await t.scrollUntilVisible(target, 180, scrollable: scroll);
  await Scrollable.ensureVisible(t.element(target), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await _show(t, key);
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> _field(WidgetTester t, String key, String value) async {
  await _show(t, key);
  await t.enterText(find.byKey(Key(key)), value);
  t.testTextInput.hide();
  await t.pumpAndSettle();
}

void main() {
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late ProviderContainer container;
  Future<void> open(WidgetTester t, (double, double, String) spec, {bool signed = true}) async {
    identity = TestIdentityRepository()..restored = signed ? signingIdentity : null;
    orders = TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000');
    addTearDown(identity.dispose);
    container = setup(
      t,
      width: spec.$1,
      scale: 1.5,
      language: Locale(spec.$3),
      identityRepository: identity,
      liveOrderRepository: orders,
      liveClock: () => liveOrderClock,
    );
    t.view.physicalSize = Size(spec.$1, spec.$2);
    await launch(t, container);
    openLiveOrder(t.element(find.byType(Navigator).first), 'BTCUSDT');
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    expect(t.takeException(), null);
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump();
  }

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    for (final mode in LiveOrderEntryMode.values.where((m) => m.inline)) {
      testWidgets('$mode first entry defaults and signed submission through actual menu $spec', (
        t,
      ) async {
        await open(t, spec);
        expect(find.byKey(const Key('order-mode-menu')), findsNothing);
        expect(
          t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).remembered,
          LiveOrderEntryMode.stopLimit,
        );
        await chooseOrderMode(t, mode);
        expect(orders.reads, 0);
        expect(orders.submits, 0);
        expect(identity.wallets, 0);
        await _tap(t, 'live-order-read');
        expect(orders.reads, 1);
        await _show(t, 'live-order-quantity');
        expect(
          t.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
          '',
        );
        expect(t.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-quote'))).selected, true);
        if (!mode.marketExecution) {
          await _show(t, 'live-order-price');
          expect(
            t.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
            '80001',
          );
          final policy = t.widget<DropdownButton<LiveOrderTimeInForce>>(
            find.byKey(const Key('live-order-policy')),
          );
          expect(policy.value, mode.defaultPolicy);
          if (mode == LiveOrderEntryMode.postOnly) expect(policy.onChanged, null);
        }
        if (mode.conditional) {
          await _show(t, 'live-order-trigger-price');
          expect(
            t.widget<TextField>(find.byKey(const Key('live-order-trigger-price'))).controller!.text,
            '',
          );
          expect(
            t
                .widget<DropdownButton<LiveOrderTriggerBasis>>(
                  find.byKey(const Key('live-order-trigger-basis')),
                )
                .value,
            LiveOrderTriggerBasis.mark,
          );
          await _field(t, 'live-order-trigger-price', '81000');
        }
        if (mode == LiveOrderEntryMode.trailing) {
          await _show(t, 'live-trailing-rate');
          expect(
            t.widget<TextField>(find.byKey(const Key('live-trailing-rate'))).controller!.text,
            '',
          );
          await _show(t, 'live-trailing-activation');
          expect(
            t.widget<TextField>(find.byKey(const Key('live-trailing-activation'))).controller!.text,
            '',
          );
          await _field(t, 'live-trailing-rate', '1');
        }
        await selectLiveBase(t);
        await _field(t, 'live-order-quantity', '0.001');
        await _tap(t, 'live-order-review');
        expect(orders.submits, 0);
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('live-order-confirm')));
        await t.tap(find.byKey(const Key('live-order-confirm')));
        await t.pumpAndSettle();
        expect(orders.submits, 1);
        final intent = orders.lastIntent!;
        expect(liveOrderEntryMode(intent.draft), mode);
        expect(intent.parameters['quantity'], '0.001');
        expect(intent.parameters['type'], switch (mode) {
          LiveOrderEntryMode.limit || LiveOrderEntryMode.postOnly => 'LIMIT',
          LiveOrderEntryMode.market => 'MARKET',
          LiveOrderEntryMode.stopLimit => 'STOP',
          LiveOrderEntryMode.stopMarket => 'STOP_MARKET',
          _ => 'TRAILING_STOP_MARKET',
        });
        if (mode == LiveOrderEntryMode.postOnly) expect(intent.parameters['timeInForce'], 'GTX');
        if (mode.marketExecution) expect(intent.parameters.containsKey('price'), false);
        if (mode.conditional || mode == LiveOrderEntryMode.trailing) {
          expect(intent.parameters['workingType'], 'MARK_PRICE');
        }
        expect(identity.wallets, 0);
        await close(t);
      });
    }

    testWidgets('signed-out menu lists seven available entries $spec', (t) async {
      await open(t, spec, signed: false);
      await _tap(t, 'order-mode-more');
      final scroll = find
          .descendant(
            of: find.byKey(const Key('order-mode-menu')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final mode in LiveOrderEntryMode.values.where(
        (m) =>
            m != LiveOrderEntryMode.limit &&
            m != LiveOrderEntryMode.market &&
            m != LiveOrderEntryMode.chase &&
            m != LiveOrderEntryMode.twap,
      )) {
        final row = find.byKey(Key('order-mode-option-${mode.name}'));
        await t.scrollUntilVisible(row, 130, scrollable: scroll);
        await Scrollable.ensureVisible(t.element(row), alignment: .5);
        await t.pumpAndSettle();
        final tile = t.widget<ListTile>(row);
        expect(tile.enabled, isTrue);
        expect(tile.onTap, isNotNull);
      }
      expect(find.byKey(const Key('order-mode-option-chase')), findsNothing);
      expect(find.byKey(const Key('order-mode-option-twap')), findsNothing);
      Navigator.of(t.element(find.byKey(const Key('order-mode-menu')))).pop();
      await t.pumpAndSettle();
      await chooseOrderMode(t, LiveOrderEntryMode.scaled);
      expect(find.byType(ScaledOrderScreen), findsOneWidget);
      expect(orders.reads, 0);
      expect(orders.submits, 0);
      expect(identity.wallets, 0);
      await close(t);
    });
  }

  testWidgets('menu memory and input survive refresh and cancel, reset when identity changes', (
    t,
  ) async {
    await open(t, (320, 844, 'en'));
    await chooseOrderMode(t, LiveOrderEntryMode.stopMarket);
    await _tap(t, 'live-order-read');
    await _field(t, 'live-order-trigger-price', '81000');
    await _tap(t, 'live-order-read');
    await _show(t, 'live-order-trigger-price');
    expect(
      t.widget<TextField>(find.byKey(const Key('live-order-trigger-price'))).controller!.text,
      '81000',
    );
    await _tap(t, 'order-mode-more');
    Navigator.of(t.element(find.byKey(const Key('order-mode-menu')))).pop();
    await t.pumpAndSettle();
    await _show(t, 'order-mode-more');
    var selector = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector));
    expect(selector.selected, LiveOrderEntryMode.stopMarket);
    expect(selector.remembered, LiveOrderEntryMode.stopMarket);
    container.read(localeProvider.notifier).select('zh');
    await t.pumpAndSettle();
    await _show(t, 'order-mode-more');
    selector = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector));
    expect(selector.selected, LiveOrderEntryMode.stopMarket);
    expect(selector.remembered, LiveOrderEntryMode.stopMarket);
    identity.events.add(
      const AuthIdentity(id: 'other', walletAddress: accountAddress, signingAvailable: true),
    );
    await t.pumpAndSettle();
    selector = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector));
    expect(selector.selected, LiveOrderEntryMode.limit);
    expect(selector.remembered, LiveOrderEntryMode.stopLimit);
    expect(find.byKey(const Key('live-order-trigger-price')), findsNothing);
    expect(orders.submits, 0);
    await close(t);
  });

  testWidgets('captured menu callback is ignored while signed read is pending', (t) async {
    await open(t, (390, 844, 'en'));
    final captured = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).onSelected;
    orders.readGate = Completer<void>();
    await _show(t, 'live-order-read');
    await t.tap(find.byKey(const Key('live-order-read')));
    await t.pump();
    captured(LiveOrderEntryMode.postOnly);
    captured(LiveOrderEntryMode.scaled);
    await t.pump();
    expect(find.byType(ScaledOrderScreen), findsNothing);
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    t.state<ScrollableState>(scroll).position.jumpTo(0);
    await t.pump();
    expect(
      t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).selected,
      LiveOrderEntryMode.limit,
    );
    expect(t.widget<ChoiceChip>(find.byKey(const Key('order-mode-more'))).onSelected, null);
    orders.readGate!.complete();
    await t.pumpAndSettle();
    expect(orders.reads, 1);
    expect(orders.submits, 0);
    await close(t);
  });

  testWidgets('open menu survives recycled selector; disposed owner ignores captured selection', (
    t,
  ) async {
    await open(t, (320, 844, 'en'));
    await _tap(t, 'live-order-read');
    await _tap(t, 'order-mode-more');
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    t
        .state<ScrollableState>(scroll)
        .position
        .jumpTo(t.state<ScrollableState>(scroll).position.maxScrollExtent);
    await t.pumpAndSettle();
    expect(find.byType(LiveOrderModeSelector), findsNothing);
    await t.tap(find.byKey(const Key('order-mode-option-postOnly')));
    await t.pumpAndSettle();
    await _show(t, 'order-mode-more');
    final selector = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector));
    expect(selector.selected, LiveOrderEntryMode.postOnly);
    final captured = selector.onSelected;
    Navigator.of(t.element(find.byType(LiveOrderScreen))).pop();
    await t.pumpAndSettle();
    captured(LiveOrderEntryMode.scaled);
    captured(LiveOrderEntryMode.market);
    await t.pumpAndSettle();
    expect(find.byType(ScaledOrderScreen), findsNothing);
    expect(orders.reads, 1);
    expect(orders.submits, 0);
    await close(t);
  });
}

import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/trade_fixture.dart';
import '../../support/aster_account.dart';
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

  Future<void> field(WidgetTester tester, String key, String text) async {
    if (key == 'live-order-quantity') await selectLiveBase(tester);
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String value) async {
    await tap(tester, 'live-order-pricing');
    await tester.ensureVisible(find.text(value).last);
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label) async {
    await chooseOrderExecution(
      tester,
      label == AppLocalizations.of(tester.element(find.byType(LiveOrderScreen))).market,
    );
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer container, {
    bool close = false,
    bool conditional = false,
  }) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    if (conditional) {
      openPositionTriggers(context, 'BTCUSDT', 'BOTH');
    } else if (close) {
      openLiveClose(context, 'BTCUSDT', 'BOTH');
    } else {
      openLiveOrder(context, 'BTCUSDT');
    }
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  for (final scenario in [
    (language: 'en', width: 320.0, height: 844.0, close: false, conditional: false),
    (language: 'zh', width: 320.0, height: 844.0, close: true, conditional: false),
    (language: 'en', width: 844.0, height: 390.0, close: true, conditional: true),
    (language: 'zh', width: 768.0, height: 1024.0, close: false, conditional: false),
  ]) {
    testWidgets('ordinary BBO read/review/cancel/unknown query fits $scenario', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final repository = TestLiveOrderRepository()
        ..context = scenario.close ? liveCloseContext() : liveContext(bid: '79999', ask: '80001')
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      final container = setup(
        tester,
        width: scenario.width,
        scale: 1.5,
        language: Locale(scenario.language),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      tester.view.physicalSize = Size(scenario.width, scenario.height);
      await open(tester, container, close: scenario.close, conditional: scenario.conditional);
      final l10n = messages(tester);
      if (scenario.close) await type(tester, l10n.limit);
      await field(tester, 'live-order-quantity', '0.001');
      if (scenario.conditional) await field(tester, 'live-order-trigger-price', '79000');
      await choose(tester, l10n.attachedEntryQueue(1));
      expect(find.byKey(const Key('live-order-price')), findsNothing);
      await tap(tester, 'live-order-review');
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text(l10n.attachedEntryQueue(1))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(l10n.liveOrderPegHint)),
        findsOneWidget,
      );
      expect(find.descendant(of: dialog, matching: find.text('0')), findsNothing);
      await tester.ensureVisible(find.text(l10n.cancel));
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(repository.submits, 0);
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-pricing');
      expect(
        tester.widget<DropdownButton<String>>(find.byKey(const Key('live-order-pricing'))).value,
        'QUEUE_1',
      );
      await tap(tester, 'live-order-review');
      await tester.ensureVisible(find.byKey(const Key('live-order-confirm')));
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      expect(repository.submits, 1);
      final frozen = repository.lastIntent!;
      expect(frozen.draft.peg, LiveOrderPeg.queue);
      expect(frozen.draft.price, '');
      expect(frozen.draft.reducing, scenario.close);
      expect(frozen.draft.trigger != null, scenario.conditional);
      await visible(tester, 'live-order-pricing');
      expect(
        tester
            .widget<DropdownButton<String>>(find.byKey(const Key('live-order-pricing')))
            .onChanged,
        null,
      );
      repository.result = LiveOrderResult(
        orderId: '12345',
        status: 'NEW',
        executedQuantity: Decimal.zero,
      );
      await tap(tester, 'live-order-recheck');
      expect(repository.submits, 1);
      expect(repository.checks, 1);
      expect(repository.lastIntent!.clientOrderId, frozen.clientOrderId);
      expect(repository.lastIntent!.draft.peg, LiveOrderPeg.queue);
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  for (final language in ['en', 'zh']) {
    testWidgets(
      'ordinary pricing preserves manual input across market/BBO and isolates attachment $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final repository = TestLiveOrderRepository();
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
        );
        await open(tester, container);
        final l10n = messages(tester);
        await field(tester, 'live-order-quantity', '0.001');
        await field(tester, 'live-order-price', '80000');
        await choose(tester, l10n.attachedEntryCounterparty(1));
        await type(tester, l10n.market);
        expect(find.byKey(const Key('live-order-pricing')), findsNothing);
        await tap(tester, 'live-order-review');
        expect(
          find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.liveOrderPegHint)),
          findsNothing,
        );
        await tester.ensureVisible(find.text(l10n.cancel));
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        await type(tester, l10n.limit);
        await choose(tester, l10n.attachedEntryFixed);
        await visible(tester, 'live-order-price');
        expect(
          tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
          '80000',
        );
        await choose(tester, l10n.attachedEntryCounterparty(1));
        await tap(tester, 'live-order-attached');
        expect(find.byKey(const Key('live-order-pricing')), findsNothing);
        await visible(tester, 'attached-entry-pricing');
        expect(
          tester
              .widget<DropdownButton<String>>(find.byKey(const Key('attached-entry-pricing')))
              .value,
          'fixed',
        );
        await tap(tester, 'live-order-attached');
        await visible(tester, 'live-order-pricing');
        expect(
          tester.widget<DropdownButton<String>>(find.byKey(const Key('live-order-pricing'))).value,
          'COUNTERPARTY_1',
        );
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('live-order-pricing')), findsNothing);
        expect(repository.submits, 0);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}

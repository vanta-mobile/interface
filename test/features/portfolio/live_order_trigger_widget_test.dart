import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
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
    final scrollable = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 180, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (await toggleOrderMode(tester, key)) return;
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> open(WidgetTester tester, ProviderContainer container, {String? side}) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    if (side == null) {
      openLiveOrder(context, 'BTCUSDT');
    } else {
      openPositionTriggers(context, 'BTCUSDT', side);
    }
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    if (key == 'live-order-quantity') await selectLiveBase(tester);
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> market(WidgetTester tester, bool value) async {
    await chooseOrderExecution(tester, value);
  }

  Future<void> kind(WidgetTester tester, LiveOrderTriggerKind value) async {
    await visible(tester, 'live-order-trigger-kind');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('live-order-trigger-kind')),
        matching: find.text(
          value == LiveOrderTriggerKind.stop
              ? l10n(tester).liveOrderStop
              : l10n(tester).liveOrderTakeProfit,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mark(WidgetTester tester) async {
    await tap(tester, 'live-order-trigger-basis');
    await tester.tap(find.text(l10n(tester).openOrdersMarkPrice).last);
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final language in ['en', 'zh']) {
    for (final triggerKind in LiveOrderTriggerKind.values) {
      for (final marketOrder in [false, true]) {
        testWidgets(
          'conditional review and recovery, 320 enlarged/landscape: $language $triggerKind market=$marketOrder',
          (tester) async {
            final identity = TestIdentityRepository()..restored = signingIdentity;
            final repository = TestLiveOrderRepository()
              ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
            addTearDown(identity.dispose);
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
            await tap(tester, 'live-order-conditional');
            await kind(tester, triggerKind);
            await mark(tester);
            final trigger = triggerKind == LiveOrderTriggerKind.stop ? '81000' : '79000';
            await field(tester, 'live-order-trigger-price', trigger);
            await tap(tester, 'live-order-trigger-protect');
            await market(tester, marketOrder);
            await field(tester, 'live-order-quantity', '0.001');
            if (!marketOrder) await field(tester, 'live-order-price', '80000');
            await tap(tester, 'live-order-review');
            final messages = l10n(tester), dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget);
            expect(
              find.descendant(of: dialog, matching: find.text(messages.liveOrderConditionalHint)),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: dialog,
                matching: find.text(
                  '${triggerKind == LiveOrderTriggerKind.stop ? '≥' : '≤'} $trigger USDT',
                ),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), null);
            tester.view.physicalSize = const Size(844, 390);
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            await tester.tap(find.text(messages.cancel));
            await tester.pumpAndSettle();
            expect(repository.submits, 0);
            await tap(tester, 'live-order-review');
            await tester.tap(find.byKey(const Key('live-order-confirm')));
            await tester.pumpAndSettle();
            expect(repository.lastIntent!.draft.trigger!.price, trigger);
            expect(repository.lastIntent!.draft.trigger!.basis, LiveOrderTriggerBasis.mark);
            expect(repository.lastIntent!.draft.trigger!.protect, true);
            expect(repository.lastIntent!.draft.market, marketOrder);
            expect(repository.lastIntent!.parameters['price'], marketOrder ? null : '80000');
            await expectOrderModeLocked(tester);
            final id = repository.lastIntent!.clientOrderId;
            repository.result = LiveOrderResult(
              orderId: '12345',
              status: 'NEW',
              executedQuantity: Decimal.zero,
            );
            await tap(tester, 'live-order-recheck');
            expect(repository.lastIntent!.clientOrderId, id);
            expect(repository.lastIntent!.draft.trigger!.price, trigger);
            expect(repository.submits, 1);
            expect(repository.checks, 1);
            expect(identity.wallets, 0);
            expect(tester.takeException(), null);
            await dispose(tester, container);
          },
        );
      }
    }
  }

  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      testWidgets('position TP/SL is fixed to original side: short=$short hedge=$hedge', (
        tester,
      ) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = TestLiveOrderRepository()
          ..context = liveCloseContext(short: short, hedge: hedge);
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(short ? 'zh' : 'en'),
          identityRepository: identity,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
        );
        final side = hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH';
        await open(tester, container, side: side);
        await visible(tester, 'live-order-trigger-price');
        expect(
          tester.widget<SwitchListTile>(find.byKey(const Key('live-order-conditional'))).value,
          true,
        );
        expect(
          tester.widget<SwitchListTile>(find.byKey(const Key('live-order-conditional'))).onChanged,
          null,
        );
        expect(find.byKey(const Key('live-order-price')), findsNothing);
        await field(tester, 'live-order-trigger-price', short ? '81000' : '78000');
        await field(tester, 'live-order-quantity', '0.005');
        await tap(tester, 'live-order-review');
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.byKey(const Key('live-order-confirm')));
        await tester.pumpAndSettle();
        expect(repository.lastIncludeFunds, false);
        expect(repository.lastIntent!.parameters['type'], 'STOP_MARKET');
        expect(repository.lastIntent!.parameters['positionSide'], side);
        expect(repository.lastIntent!.parameters['reduceOnly'], hedge ? null : 'true');
        expect(repository.lastIntent!.parameters['side'], short ? 'BUY' : 'SELL');
        expect(tester.takeException(), null);
        await dispose(tester, container);
      });
    }
  }

  testWidgets(
    'refresh preserves trigger input; missing references require explicit basis/protection choice',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      await tap(tester, 'live-order-conditional');
      await tap(tester, 'live-order-trigger-basis');
      await tester.tap(find.text(l10n(tester).openOrdersLastPrice).last);
      await tester.pumpAndSettle();
      await field(tester, 'live-order-trigger-price', '81000');
      await tap(tester, 'live-order-trigger-protect');
      await field(tester, 'live-order-quantity', '0.001');
      await field(tester, 'live-order-price', '80000');
      repository.context = liveContext(lastPrice: null, protection: null);
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-trigger-price');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('live-order-trigger-price')))
            .controller!
            .text,
        '81000',
      );
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      await tap(tester, 'live-order-trigger-protect');
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      await mark(tester);
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        isNotNull,
      );
      expect(repository.submits, 0);
      await dispose(tester, container);
    },
  );

  for (final language in ['en', 'zh']) {
    testWidgets('entire close scope, preserved input and unknown recovery: $language', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()
        ..context = liveCloseContext(hedge: true)
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(language),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container, side: 'LONG');
      await field(tester, 'live-order-quantity', '0.005');
      await field(tester, 'live-order-trigger-price', '78000');
      await tap(tester, 'live-trigger-calculator');
      await field(tester, 'live-trigger-calculation-input', '-5');
      await tap(tester, 'live-order-entire-close');
      expect(find.byKey(const Key('live-order-quantity')), findsNothing);
      expect(find.byKey(const Key('live-close-percentage')), findsNothing);
      expect(find.byKey(const Key('live-close-fraction-50')), findsNothing);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byKey(const Key('live-order-type')))
            .onSelectionChanged,
        null,
      );
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-entire-close');
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('live-order-entire-close'))).value,
        true,
      );
      await tap(tester, 'live-order-review');
      final messages = l10n(tester), dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text(messages.liveEntireQuantity)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text(messages.liveEntireHint)),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.tap(find.text(messages.cancel));
      await tester.pumpAndSettle();
      expect(repository.submits, 0);
      await tap(tester, 'live-order-entire-close');
      await visible(tester, 'live-order-quantity');
      expect(
        tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
        '0.005',
      );
      await market(tester, false);
      await visible(tester, 'live-order-entire-close');
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('live-order-entire-close'))).onChanged,
        null,
      );
      await market(tester, true);
      await tap(tester, 'live-order-entire-close');
      await tap(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      expect(repository.lastIntent!.draft.entireClose, true);
      expect(repository.lastIntent!.parameters['quantity'], null);
      final id = repository.lastIntent!.clientOrderId;
      await visible(tester, 'live-trigger-calculation-input');
      expect(
        tester.widget<TextField>(find.byKey(const Key('live-trigger-calculation-input'))).readOnly,
        true,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('live-trigger-calculation-apply')))
            .onPressed,
        null,
      );
      await visible(tester, 'live-order-entire-close');
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('live-order-entire-close'))).onChanged,
        null,
      );
      repository.result = LiveOrderResult(
        orderId: '12345',
        status: 'FILLED',
        executedQuantity: Decimal.parse('0.02'),
      );
      await tap(tester, 'live-order-recheck');
      expect(repository.lastIntent!.clientOrderId, id);
      expect(repository.submits, 1);
      expect(repository.checks, 1);
      expect(find.text(messages.liveEntireQueryScope), findsOneWidget);
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await dispose(tester, container);
    });

    testWidgets('calculator previews, applies and refreshes without rewriting trigger: $language', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()..context = liveCloseContext();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(language),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container, side: 'BOTH');
      await field(tester, 'live-order-quantity', '0.005');
      await field(tester, 'live-order-trigger-price', '78000');
      await tap(tester, 'live-trigger-calculator');
      await field(tester, 'live-trigger-calculation-input', '-5');
      await visible(tester, 'live-trigger-calculated-price');
      expect(find.text('78000 USDT'), findsWidgets);
      await field(tester, 'live-trigger-calculation-input', '-4');
      await visible(tester, 'live-order-trigger-price');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('live-order-trigger-price')))
            .controller!
            .text,
        '78000',
      );
      await tap(tester, 'live-trigger-calculation-apply');
      await visible(tester, 'live-order-trigger-price');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('live-order-trigger-price')))
            .controller!
            .text,
        '78200',
      );
      expect(repository.submits, 0);
      repository.context = liveCloseContext(quantity: '0.02');
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-trigger-calculation-input');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('live-trigger-calculation-input')))
            .controller!
            .text,
        '-4',
      );
      await tap(tester, 'live-order-entire-close');
      await visible(tester, 'live-trigger-calculated-price');
      expect(find.text('78800 USDT'), findsWidgets);
      await visible(tester, 'live-order-trigger-price');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('live-order-trigger-price')))
            .controller!
            .text,
        '78200',
      );
      await visible(tester, 'live-trigger-calculation-mode');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('live-trigger-calculation-mode')),
          matching: find.text(l10n(tester).triggerCalculationRoi),
        ),
      );
      await tester.pumpAndSettle();
      await field(tester, 'live-trigger-calculation-input', '-10');
      await visible(tester, 'live-trigger-calculated-price');
      expect(find.text('78210 USDT'), findsWidgets);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tap(tester, 'live-trigger-calculation-apply');
      await tap(tester, 'live-order-review');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l10n(tester).cancel));
      await tester.pumpAndSettle();
      expect(repository.submits, 0);
      await dispose(tester, container);
    });
  }

  testWidgets('turning a condition off does not send dormant trigger fields', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await tap(tester, 'live-order-conditional');
    await field(tester, 'live-order-trigger-price', '81000');
    await tap(tester, 'live-order-conditional');
    await field(tester, 'live-order-quantity', '0.001');
    await field(tester, 'live-order-price', '80000');
    await tap(tester, 'live-order-review');
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(repository.lastIntent!.parameters['type'], 'LIMIT');
    for (final key in ['stopPrice', 'workingType', 'priceProtect']) {
      expect(repository.lastIntent!.parameters.containsKey(key), false);
    }
    await dispose(tester, container);
  });
}

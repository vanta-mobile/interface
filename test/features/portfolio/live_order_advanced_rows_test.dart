import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/embedded_time_in_force_selector.dart';
import 'package:vanta/features/portfolio/presentation/live_order_embedded_controls.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';

void main() {
  Future<MainOrderLiveFixture> mount(
    WidgetTester tester, {
    bool hedge = false,
    bool expand = true,
    Widget Function(MainOrderLiveFixture f)? body,
  }) async {
    final f = MainOrderLiveFixture(
      orderRepository: TestLiveOrderRepository()..context = capacityContext(hedge: hedge),
    );
    await tester.runAsync(f.open);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: body?.call(f) ?? const LiveOrderScreen(symbol: 'BTCUSDT'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (expand) {
      await tester.tap(find.byKey(const Key('live-order-advanced')));
      await tester.pumpAndSettle();
    }
    return f;
  }

  Future<void> tapRow(WidgetTester tester, String key) async {
    final row = find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)).first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  bool checked(WidgetTester tester, String key) =>
      tester.widget<EmbeddedCheckRow>(find.byKey(Key(key))).value;

  Future<void> close(WidgetTester tester, MainOrderLiveFixture f) async {
    await tester.pumpWidget(const SizedBox());
    await f.close();
  }

  testWidgets('one-way rows share one height and exclusive options follow the latest choice', (
    tester,
  ) async {
    final f = await mount(tester);
    try {
      final heights = {
        for (final key in ['live-order-attached', 'live-order-hidden', 'live-order-reduce-only'])
          tester.getSize(find.byKey(Key(key))).height,
      };
      expect(heights, {embeddedCheckRowHeight});

      await tapRow(tester, 'live-order-attached');
      expect(checked(tester, 'live-order-attached'), isTrue);
      // Reduce only clears TP/SL; the TP/SL row stays available.
      await tapRow(tester, 'live-order-reduce-only');
      expect(checked(tester, 'live-order-reduce-only'), isTrue);
      expect(checked(tester, 'live-order-attached'), isFalse);
      // TP/SL clears Reduce only.
      await tapRow(tester, 'live-order-attached');
      expect(checked(tester, 'live-order-attached'), isTrue);
      expect(checked(tester, 'live-order-reduce-only'), isFalse);

      // Hidden keeps the policy selector in place, muted; picking GTC clears Hidden.
      await tapRow(tester, 'live-order-hidden');
      expect(checked(tester, 'live-order-hidden'), isTrue);
      final selector = find.byKey(const Key('live-order-policy'));
      expect(tester.widget<EmbeddedTimeInForceSelector>(selector).inactive, isTrue);
      expect(
        tester.getSize(find.byKey(const Key('live-order-reduce-only'))).height,
        embeddedCheckRowHeight,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byKey(const Key('time-in-force-sheet'))));
      await tester.tap(find.text(l.timeInForceGtc));
      await tester.pumpAndSettle();
      expect(checked(tester, 'live-order-hidden'), isFalse);
      expect(tester.widget<EmbeddedTimeInForceSelector>(selector).inactive, isFalse);
      expect(
        tester.widget<EmbeddedTimeInForceSelector>(selector).selected,
        LiveOrderTimeInForce.gtc,
      );
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('conditional and Post Only orders show only their designed rows', (tester) async {
    for (final (mode, hidden, policy) in [
      (LiveOrderEntryMode.stopLimit, false, true),
      (LiveOrderEntryMode.postOnly, false, false),
    ]) {
      final f = await mount(
        tester,
        body: (f) => LiveOrderForm(data: f.orders.context, mode: mode),
      );
      try {
        expect(find.byKey(const Key('live-order-attached')), findsOneWidget);
        expect(
          find.byKey(const Key('live-order-hidden')),
          hidden ? findsOneWidget : findsNothing,
          reason: '$mode',
        );
        expect(find.byKey(const Key('live-order-reduce-only')), findsOneWidget);
        expect(
          find.byKey(const Key('live-order-policy')),
          policy ? findsOneWidget : findsNothing,
          reason: '$mode',
        );
      } finally {
        await close(tester, f);
      }
    }
  });

  testWidgets('hedge mode drops Reduce only and switches between Open and Close', (tester) async {
    final f = await mount(tester, hedge: true);
    try {
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      expect(find.byKey(const Key('live-order-reduce-only')), findsNothing);
      expect(find.byKey(const Key('live-order-policy')), findsOneWidget);
      expect(find.byKey(const Key('hedge-intent')), findsOneWidget);
      expect(find.text(l.tradeOpenLong), findsOneWidget);
      expect(find.text(l.tradeOpenShort), findsOneWidget);

      await tester.tap(find.byKey(const Key('hedge-intent-close')));
      await tester.pumpAndSettle();
      expect(find.text(l.tradeCloseShort), findsOneWidget);
      expect(find.text(l.tradeCloseLong), findsOneWidget);
      // Closing takes no entry TP/SL.
      expect(find.byKey(const Key('live-order-attached')), findsNothing);

      await tester.tap(find.byKey(const Key('hedge-intent-open')));
      await tester.pumpAndSettle();
      expect(find.text(l.tradeOpenLong), findsOneWidget);
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('hedge Close starts GTC on the left and hides an empty Advanced row', (tester) async {
    for (final mode in [LiveOrderEntryMode.limit, LiveOrderEntryMode.postOnly]) {
      final f = await mount(
        tester,
        hedge: true,
        expand: mode != LiveOrderEntryMode.postOnly,
        body: (f) => LiveOrderForm(data: f.orders.context, mode: mode, closing: true),
      );
      try {
        final advanced = find.byKey(const Key('live-order-advanced'));
        if (mode == LiveOrderEntryMode.postOnly) {
          // No TP/SL, Hidden Order, Reduce only or time-in-force remains.
          expect(advanced.hitTestable(), findsNothing);
        } else {
          expect(advanced.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(find.byKey(const Key('live-order-policy'))).dx,
            tester.getTopLeft(advanced).dx,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        await close(tester, f);
      }
    }
  });

  testWidgets('market orders show no price box', (tester) async {
    final f = await mount(
      tester,
      body: (f) => LiveOrderForm(data: f.orders.context, mode: LiveOrderEntryMode.market),
    );
    try {
      expect(find.byKey(const Key('live-order-price')), findsNothing);
      expect(find.byKey(const Key('live-order-bbo')), findsNothing);
      expect(find.byKey(const Key('live-order-quantity')), findsOneWidget);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('a reached trigger price is reported under the trigger field', (tester) async {
    final f = await mount(
      tester,
      body: (f) => LiveOrderForm(data: f.orders.context, mode: LiveOrderEntryMode.stopLimit),
    );
    try {
      // The direction follows the price (above Mark: STOP, below: TAKE_PROFIT),
      // so only a trigger at Mark 100 itself is already reached.
      await tester.enterText(find.byKey(const Key('live-order-trigger-price')), '100');
      await tester.enterText(find.byKey(const Key('live-order-price')), '100');
      await tester.enterText(find.byKey(const Key('live-order-quantity')), '10');
      await tester.pumpAndSettle();
      final buy = find.byKey(const Key('main-order-review-buy'));
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderForm)));
      expect(find.text(l.liveOrderTriggerReached), findsOneWidget);
      expect(find.byKey(const Key('live-order-trigger-error')), findsOneWidget);
      expect(f.orders.submits, 0);
      // Editing the trigger clears the message.
      await tester.enterText(find.byKey(const Key('live-order-trigger-price')), '110');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-trigger-error')), findsNothing);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('an out-of-range callback rate is reported on leaving the field and on review', (
    tester,
  ) async {
    final f = await mount(
      tester,
      body: (f) => LiveOrderForm(data: f.orders.context, mode: LiveOrderEntryMode.trailing),
    );
    try {
      final rate = find.byKey(const Key('live-trailing-rate'));
      final activation = find.byKey(const Key('live-trailing-activation'));
      final error = find.byKey(const Key('live-trailing-rate-error'));
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderForm)));
      // Leaving an empty field reports nothing.
      await tester.tap(rate);
      await tester.tap(activation);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      // Typing never interrupts; leaving the field reports the range.
      await tester.enterText(rate, '6');
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      await tester.tap(activation);
      await tester.pumpAndSettle();
      expect(find.text(l.liveTrailingRateInvalid), findsOneWidget);
      // Editing clears it; a valid rate is not reported.
      await tester.enterText(rate, '5');
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      await tester.tap(activation);
      await tester.pumpAndSettle();
      expect(error, findsNothing);

      // A direction click checks again, before any read or review.
      await tester.enterText(rate, '0.05');
      await tester.enterText(find.byKey(const Key('live-order-quantity')), '10');
      await tester.pumpAndSettle();
      final buy = find.byKey(const Key('main-order-review-buy'));
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(error, findsOneWidget);
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('checked TP/SL left empty orders without TP/SL', (tester) async {
    final f = await mount(tester);
    try {
      await tapRow(tester, 'live-order-attached');
      await tester.enterText(find.byKey(const Key('live-order-price')), '100');
      await tester.enterText(find.byKey(const Key('live-order-quantity')), '10');
      await tester.pumpAndSettle();
      final buy = find.byKey(const Key('main-order-review-buy'));
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      expect(find.textContaining(l.attachedOrderCheckExits), findsNothing);
      Finder inDialog(Finder f) => find.descendant(of: find.byType(Dialog), matching: f);
      expect(inDialog(find.text(l.orderConfirmQuantity)), findsOneWidget);
      expect(inDialog(find.text(l.orderConfirmTakeProfit)), findsNothing);
      expect(inDialog(find.text(l.orderConfirmStopLoss)), findsNothing);
      expect(f.orders.submits, 0);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('TP/SL excludes BBO and Hidden Order, as on Aster', (tester) async {
    final f = await mount(tester);
    try {
      final bbo = find.byKey(const Key('live-order-bbo'));
      await tester.tap(bbo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-bbo-level')), findsOneWidget);
      await tapRow(tester, 'live-order-hidden');
      expect(checked(tester, 'live-order-hidden'), isTrue);

      // Checking TP/SL clears BBO and Hidden Order and disables BBO.
      await tapRow(tester, 'live-order-attached');
      expect(checked(tester, 'live-order-attached'), isTrue);
      expect(checked(tester, 'live-order-hidden'), isFalse);
      expect(find.byKey(const Key('live-order-bbo-level')), findsNothing);
      await tester.ensureVisible(bbo);
      await tester.tap(bbo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-bbo-level')), findsNothing);

      // Checking Hidden Order clears TP/SL; BBO is available again.
      await tapRow(tester, 'live-order-hidden');
      expect(checked(tester, 'live-order-hidden'), isTrue);
      expect(checked(tester, 'live-order-attached'), isFalse);
      await tester.ensureVisible(bbo);
      await tester.tap(bbo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-bbo-level')), findsOneWidget);

      // Hidden Order and Reduce only may be combined.
      await tapRow(tester, 'live-order-reduce-only');
      expect(checked(tester, 'live-order-hidden'), isTrue);
      expect(checked(tester, 'live-order-reduce-only'), isTrue);
      expect(f.orders.submits, 0);
    } finally {
      await close(tester, f);
    }
  });

  testWidgets('BBO with TP/SL is never offered; the level sheet lists level one only', (
    tester,
  ) async {
    final f = await mount(tester);
    try {
      await tester.tap(find.byKey(const Key('live-order-bbo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-order-bbo-level')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byKey(const Key('live-order-bbo-levels'))));
      expect(find.text(l.liveOrderBboCounterparty(1)), findsWidgets);
      expect(find.text(l.liveOrderBboQueue(1)), findsOneWidget);
      expect(find.text(l.liveOrderBboCounterparty(5)), findsNothing);
      expect(find.text(l.liveOrderBboQueue(5)), findsNothing);
    } finally {
      await close(tester, f);
    }
  });

  for (final (trigger, buy, takeProfit) in [
    ('110', true, false),
    ('90', true, true),
    ('90', false, false),
    ('110', false, true),
  ]) {
    testWidgets('trigger $trigger for ${buy ? 'buy' : 'sell'} is '
        '${takeProfit ? 'TAKE_PROFIT' : 'STOP'}', (tester) async {
      final f = await mount(
        tester,
        body: (f) => LiveOrderForm(data: f.orders.context, mode: LiveOrderEntryMode.stopLimit),
      );
      try {
        await tester.enterText(find.byKey(const Key('live-order-trigger-price')), trigger);
        await tester.enterText(find.byKey(const Key('live-order-price')), '100');
        await tester.enterText(find.byKey(const Key('live-order-quantity')), '10');
        await tester.pumpAndSettle();
        final side = find.byKey(Key('main-order-review-${buy ? 'buy' : 'sell'}'));
        await tester.ensureVisible(side);
        await tester.tap(side);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('live-order-trigger-error')), findsNothing);
        final l = AppLocalizations.of(tester.element(find.byType(LiveOrderForm)));
        // Mark 100: the confirmation shows the trigger condition the type implies.
        final rises = takeProfit != buy;
        expect(
          find.text('${l.openOrdersMarkPrice} ${rises ? '≥' : '≤'} $trigger USDT'),
          findsOneWidget,
        );
        expect(f.orders.submits, 0);
      } finally {
        await close(tester, f);
      }
    });
  }

  testWidgets('one-way mode shows no Open/Close switch', (tester) async {
    final f = await mount(tester);
    try {
      expect(find.byKey(const Key('hedge-intent')), findsNothing);
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      expect(find.text(l.long), findsOneWidget);
    } finally {
      await close(tester, f);
    }
  });
}

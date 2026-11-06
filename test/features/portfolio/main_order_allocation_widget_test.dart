import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';

import '../../support/main_order_capacity.dart';
import '../../support/main_order_form.dart';

void main() {
  late MainOrderFormFixture f;
  setUp(() => f = MainOrderFormFixture());
  tearDown(() => f.close());
  void allocationTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await f.unmount(tester);
      }
    });
  }

  allocationTest('initial slider is zero with blank input; disabled until explicit read', (
    tester,
  ) async {
    await f.open(tester);
    final slider = tester.widget<Slider>(find.byKey(const Key('main-order-percentage')));
    expect(slider.value, 0);
    expect(slider.onChanged, null);
    expect(f.input(tester), '');
    expect(f.capacities.reads, 0);
    for (final side in ['buy', 'sell']) {
      expect(
        tester.widget<FilledButton>(find.byKey(Key('main-order-review-$side'))).onPressed,
        null,
      );
    }
    await f.tap(tester, 'main-order-capacity-read');
    expect(
      tester.widget<Slider>(find.byKey(const Key('main-order-percentage'))).onChanged,
      isNotNull,
    );
    expect(f.input(tester), '');
    expect(f.orders.submits, 0);
  });
  allocationTest(
    '20 percent shows independent quantities and selected quote amount; units preserve exact base',
    (tester) async {
      await f.open(tester);
      await f.tap(tester, 'main-order-capacity-read');
      await f.select(tester);
      expect(f.input(tester), '181.901');
      expect(
        find.descendant(
          of: find.byKey(const Key('main-order-maximum-buy')),
          matching: find.text('≈ 909.909 USDT'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('main-order-review-buy')),
          matching: find.text('≈ 181.901 USDT'),
        ),
        findsOneWidget,
      );
      expect(find.text('1.801 BTC'), findsWidgets);
      expect(find.text('1.98 BTC'), findsWidgets);
      await f.tap(tester, 'live-order-unit-base');
      expect(f.input(tester), '1.801');
      expect(
        find.descendant(
          of: find.byKey(const Key('main-order-maximum-buy')),
          matching: find.text('9.009 BTC'),
        ),
        findsOneWidget,
      );
      await f.tap(tester, 'live-order-unit-quote');
      expect(f.input(tester), '181.901');
      expect(f.capacities.reads, 1);
    },
  );
  allocationTest('editing ratio amount returns to manual mode and retains independent unit input', (
    tester,
  ) async {
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    await f.field(tester, 'live-order-quantity', '202.000');
    expect(f.container.read(mainOrderAllocationProvider).percent, null);
    expect(f.input(tester), '202.000');
    await f.tap(tester, 'live-order-unit-base');
    expect(f.input(tester), '');
    await f.field(tester, 'live-order-quantity', '3.000');
    await f.tap(tester, 'live-order-unit-quote');
    expect(f.input(tester), '202.000');
    expect(f.capacities.reads, 1);
  });
  for (final buy in [true, false]) {
    allocationTest('click direction $buy freshly checks and confirms its frozen quantity', (
      tester,
    ) async {
      await f.open(tester);
      await f.tap(tester, 'main-order-capacity-read');
      await f.select(tester);
      await f.tap(tester, buy ? 'main-order-review-buy' : 'main-order-review-sell');
      expect(f.capacities.reads, 2);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(buy ? '1.801' : '1.98')),
        findsOneWidget,
      );
      expect(f.orders.submits, 0);
      await f.confirm(tester);
      expect(f.orders.submits, 1);
      expect(f.orders.lastIntent!.draft.buy, buy);
      expect(f.orders.lastIntent!.draft.quantity, buy ? '1.801' : '1.98');
      expect(f.orders.lastIntent!.draft.price, '101');
      expect(f.container.read(mainOrderAllocationProvider).percent, 0);
      expect(f.input(tester), '');
    });
  }
  allocationTest(
    'higher fresh maximum keeps confirmation at clicked quantity rather than resizing',
    (tester) async {
      await f.open(tester);
      await f.tap(tester, 'main-order-capacity-read');
      await f.select(tester);
      f.capacities.transform = (context) {
        final payload = capacityAccountPayload();
        (payload['assets'] as List).single['availableBalance'] = '200';
        return assembledCapacity(context: context, payload: payload);
      };
      await f.tap(tester, 'main-order-review-buy');
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('1.801')),
        findsOneWidget,
      );
      await f.confirm(tester);
      expect(f.orders.lastIntent!.draft.quantity, '1.801');
    },
  );
  allocationTest('cancelling review preserves percentage and never submits', (tester) async {
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    await f.tap(tester, 'main-order-review-buy');
    await f.cancel(tester);
    expect(f.container.read(mainOrderAllocationProvider).percent, 20);
    expect(f.input(tester), '181.901');
    expect(f.orders.submits, 0);
  });
  allocationTest('lower fresh maximum shows a safe failure and never opens confirmation', (
    tester,
  ) async {
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    f.capacities.transform = (context) {
      final payload = capacityAccountPayload();
      (payload['assets'] as List).single['availableBalance'] = '1';
      return assembledCapacity(context: context, payload: payload);
    };
    await f.tap(tester, 'main-order-review-buy');
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.container.read(mainOrderAllocationProvider).failure!.key, 'liveCapacityAboveMaximum');
    expect(f.container.read(mainOrderAllocationProvider).percent, 20);
    expect(f.orders.submits, 0);
  });
  allocationTest('cancel during refresh re-enables input and drops late review', (tester) async {
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    f.capacities.gate = Completer<void>();
    await f.visible(tester, 'main-order-review-buy');
    await tester.tap(find.byKey(const Key('main-order-review-buy')));
    await tester.pump();
    expect(f.container.read(mainOrderAllocationProvider).preparing, true);
    await tester.ensureVisible(find.byKey(const Key('main-order-capacity-stop')));
    await tester.tap(find.byKey(const Key('main-order-capacity-stop')));
    await tester.pumpAndSettle();
    expect(f.container.read(mainOrderAllocationProvider).preparing, false);
    expect(f.input(tester), '181.901');
    f.capacities.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.orders.submits, 0);
  });
  allocationTest('expired confirmation and expired wallet prompt cannot submit', (tester) async {
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    await f.tap(tester, 'main-order-review-buy');
    await tester.pump(const Duration(seconds: 30));
    await f.confirm(tester);
    expect(f.orders.submits, 0);
  });
  allocationTest('skip-confirmation preference still refreshes and checks before signing', (
    tester,
  ) async {
    f.preferences.values[OrderConfirmationKind.limit] = false;
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    await f.tap(tester, 'main-order-review-sell');
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.capacities.reads, 2);
    expect(f.orders.lastIntent!.draft.quantity, '1.98');
    expect(f.orders.lastIntent!.draft.buy, false);
  });
  allocationTest('unknown result preserves ratio and input, and disables further submission', (
    tester,
  ) async {
    f.orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await f.open(tester);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester);
    await f.tap(tester, 'main-order-review-buy');
    await f.confirm(tester);
    expect(f.container.read(mainOrderAllocationProvider).percent, 20);
    expect(f.input(tester), '181.901');
    expect(tester.widget<Slider>(find.byKey(const Key('main-order-percentage'))).onChanged, null);
    expect(tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).readOnly, true);
    expect(f.orders.submits, 1);
  });
  allocationTest('market ratio uses per-side book conversion and fixed MARKET confirmation', (
    tester,
  ) async {
    await f.open(tester, mode: LiveOrderEntryMode.market);
    await f.tap(tester, 'main-order-capacity-read');
    await f.select(tester, 100);
    expect(f.input(tester), '905.364');
    await f.tap(tester, 'main-order-review-sell');
    await f.confirm(tester);
    expect(f.orders.lastIntent!.draft.market, true);
    expect(f.orders.lastIntent!.draft.quantity, '9.174');
  });
  for (final locale in ['en', 'zh']) {
    for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
      allocationTest('ratio control and frozen review fit enlarged $locale $size', (tester) async {
        await f.open(tester, locale: locale, size: size, scale: 1.5);
        await f.tap(tester, 'main-order-capacity-read');
        await f.select(tester);
        await f.tap(tester, 'main-order-review-sell');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
        await f.cancel(tester);
        expect(tester.takeException(), null);
      });
    }
  }
}

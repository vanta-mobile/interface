import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_capacity.dart';
import '../../support/main_order_form.dart';

void main() {
  late MainOrderFormFixture f;
  setUp(() => f = MainOrderFormFixture());
  tearDown(() => f.close());
  void formTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await f.unmount(tester);
      }
    });
  }

  FilledButton button(WidgetTester tester, bool buy) =>
      tester.widget<FilledButton>(find.byKey(Key('main-order-review-${buy ? 'buy' : 'sell'}')));
  Future<void> base(WidgetTester tester, [String amount = '2.000']) async {
    await f.tap(tester, 'live-order-unit-base');
    await f.field(tester, 'live-order-quantity', amount);
  }

  for (final buy in [true, false]) {
    for (final mode in LiveOrderEntryMode.values.where((mode) => mode.inline)) {
      formTest('manual $mode side $buy reads fresh capacity without a prior read', (tester) async {
        await f.open(tester, mode: mode);
        if (!mode.marketExecution) await f.field(tester, 'live-order-price', '101');
        if (mode.conditional) {
          await f.field(tester, 'live-order-trigger-price', buy ? '110' : '90');
        }
        if (mode == LiveOrderEntryMode.trailing) await f.field(tester, 'live-trailing-rate', '1');
        await base(tester);
        expect(f.capacities.reads, 0);
        expect(f.container.read(mainOrderAllocationProvider).percent, null);
        expect(button(tester, buy).onPressed, isNotNull);
        await f.tap(tester, 'main-order-review-${buy ? 'buy' : 'sell'}');
        expect(f.capacities.reads, 1);
        final review = f.container.read(mainOrderAllocationProvider).review!;
        expect(review.intent.draft.buy, buy);
        expect(review.intent.draft.quantity, '2.000');
        expect(review.intent.draft.market, mode.marketExecution);
        expect(review.intent.draft.trigger != null, mode.conditional);
        expect(review.intent.draft.trailing != null, mode == LiveOrderEntryMode.trailing);
        expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
        await f.confirm(tester);
        expect(f.orders.submits, 1);
        expect(f.orders.lastIntent!.draft, same(review.intent.draft));
        expect(f.input(tester), '2.000');
      });
    }
    formTest('manual market quote side $buy freezes the matching book conversion', (tester) async {
      await f.open(tester, mode: LiveOrderEntryMode.market);
      await f.field(tester, 'live-order-quantity', '101.000');
      expect(button(tester, buy).onPressed, isNotNull);
      await f.tap(tester, 'main-order-review-${buy ? 'buy' : 'sell'}');
      final review = f.container.read(mainOrderAllocationProvider).review!;
      expect(review.intent.draft.quantity, buy ? '1' : '1.02');
      await f.confirm(tester);
      expect(f.orders.lastIntent!.draft.buy, buy);
      expect(f.orders.lastIntent!.draft.quantity, buy ? '1' : '1.02');
      expect(f.input(tester), '101.000');
    });
  }

  formTest('manual main submit button also checks fresh limits and never bypasses review', (
    tester,
  ) async {
    await f.open(tester);
    await base(tester);
    await f.tap(tester, 'live-order-review');
    expect(f.capacities.reads, 1);
    expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
    await f.cancel(tester);
    expect(f.input(tester), '2.000');
    expect(f.orders.submits, 0);
  });
  formTest('same manual input may enable only the side meeting minimum notional', (tester) async {
    await f.open(tester, mode: LiveOrderEntryMode.market);
    await f.field(tester, 'live-order-quantity', '5');
    expect(button(tester, true).onPressed, null);
    expect(button(tester, false).onPressed, isNotNull);
    expect(f.capacities.reads, 0);
    await f.tap(tester, 'main-order-review-sell');
    await f.confirm(tester);
    expect(f.orders.lastIntent!.draft.quantity, '0.05');
    expect(f.orders.lastIntent!.draft.buy, false);
  });
  formTest('manual refresh freezes size even when latest capacity grows', (tester) async {
    await f.open(tester);
    await f.field(tester, 'live-order-quantity', '202.000');
    f.capacities.transform = (context) {
      final payload = capacityAccountPayload();
      (payload['assets'] as List).single['availableBalance'] = '200';
      return assembledCapacity(context: context, payload: payload);
    };
    await f.tap(tester, 'main-order-review-buy');
    expect(f.container.read(mainOrderAllocationProvider).review!.intent.draft.quantity, '2');
    await f.confirm(tester);
    expect(f.orders.lastIntent!.draft.quantity, '2');
    expect(f.input(tester), '202.000');
    expect(f.container.read(mainOrderAllocationProvider).percent, null);
  });
  for (final locale in ['en', 'zh']) {
    for (final quote in [true, false]) {
      formTest(
        'manual $locale maximum error uses latest ${quote ? 'quote' : 'base'} units and retains input',
        (tester) async {
          await f.open(tester, locale: locale);
          if (quote) {
            await f.field(tester, 'live-order-quantity', '202.000');
          } else {
            await base(tester);
          }
          f.capacities.transform = (context) {
            final payload = capacityAccountPayload();
            (payload['assets'] as List).single['availableBalance'] = '1';
            return assembledCapacity(context: context, payload: payload);
          };
          await f.tap(tester, 'main-order-review-buy');
          expect(find.byType(AlertDialog), findsNothing);
          final l10n = AppLocalizations.of(
            tester.element(find.byKey(const Key('main-order-capacity'))),
          );
          expect(
            find.text(
              l10n.liveAllocationMaximumChanged(
                l10n.long,
                quote ? '≈ 9.09' : '0.09',
                quote ? 'USDT' : 'BTC',
              ),
            ),
            findsOneWidget,
          );
          expect(f.input(tester), quote ? '202.000' : '2.000');
          expect(f.orders.submits, 0);
          // A later click must refresh even if the old maximum was exceeded.
          f.capacities.transform = null;
          await f.tap(tester, 'main-order-review-buy');
          expect(f.capacities.reads, 2);
          expect(find.byType(AlertDialog), findsOneWidget);
          await f.cancel(tester);
        },
      );
    }
  }
  formTest('wallet rejection reading manual limits preserves both independent raw inputs', (
    tester,
  ) async {
    await f.open(tester);
    await f.field(tester, 'live-order-quantity', '202.000');
    await base(tester, '3.000');
    f.capacities.failure = const AccountReadFailure('authWalletRejected');
    await f.tap(tester, 'main-order-review-buy');
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.input(tester), '3.000');
    await f.tap(tester, 'live-order-unit-quote');
    expect(f.input(tester), '202.000');
    expect(f.orders.submits, 0);
  });
  formTest('manual refresh cancel disables repeat clicks then discards its late response', (
    tester,
  ) async {
    await f.open(tester);
    await base(tester);
    f.capacities.gate = Completer<void>();
    await f.visible(tester, 'main-order-review-buy');
    await tester.tap(find.byKey(const Key('main-order-review-buy')));
    await tester.pump();
    expect(button(tester, true).onPressed, null);
    expect(button(tester, false).onPressed, null);
    expect(tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed, null);
    expect(
      find.descendant(
        of: find.byKey(const Key('main-order-review-buy')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).readOnly, true);
    await tester.ensureVisible(find.byKey(const Key('main-order-capacity-stop')));
    await tester.tap(find.byKey(const Key('main-order-capacity-stop')));
    await tester.pumpAndSettle();
    expect(f.input(tester), '2.000');
    f.capacities.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.orders.submits, 0);
    expect(button(tester, true).onPressed, isNotNull);
  });
  formTest('manual skip-confirmation preference retains fresh check and exact direction', (
    tester,
  ) async {
    f.preferences.values[OrderConfirmationKind.limit] = false;
    await f.open(tester);
    await base(tester);
    await f.tap(tester, 'main-order-review-sell');
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.capacities.reads, 1);
    expect(f.orders.lastIntent!.draft.buy, false);
    expect(f.orders.lastIntent!.draft.quantity, '2.000');
  });
  formTest('manual unknown result preserves input and only rechecks original ID', (tester) async {
    f.orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await f.open(tester);
    await base(tester);
    await f.tap(tester, 'main-order-review-buy');
    await f.confirm(tester);
    final id = f.orders.lastIntent!.clientOrderId;
    expect(f.input(tester), '2.000');
    expect(f.container.read(mainOrderAllocationProvider).percent, null);
    expect(button(tester, true).onPressed, null);
    expect(button(tester, false).onPressed, null);
    await f.container.read(liveOrderProvider.notifier).recheck();
    expect(f.orders.lastIntent!.clientOrderId, id);
    expect(f.orders.checks, 1);
    expect(f.orders.submits, 1);
    expect(f.capacities.reads, 1);
  });
  for (final locale in ['en', 'zh']) {
    for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
      formTest('manual dual action and frozen confirmation fit enlarged $locale $size', (
        tester,
      ) async {
        await f.open(
          tester,
          locale: locale,
          size: size,
          scale: 1.5,
          mode: LiveOrderEntryMode.market,
        );
        await f.field(tester, 'live-order-quantity', '101.000');
        await f.tap(tester, 'main-order-review-sell');
        expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
        await f.cancel(tester);
        expect(f.input(tester), '101.000');
        expect(tester.takeException(), null);
      });
    }
  }
}

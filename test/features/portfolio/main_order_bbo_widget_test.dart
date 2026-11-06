import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
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

  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byKey(const Key('main-order-capacity'))));
  Future<void> peg(WidgetTester tester, LiveOrderPeg? selected) async {
    await f.tap(tester, 'live-order-pricing');
    final l10n = messages(tester);
    await tester.tap(
      find
          .text(
            selected == null
                ? l10n.attachedEntryFixed
                : selected == LiveOrderPeg.counterparty
                ? l10n.attachedEntryCounterparty(1)
                : l10n.attachedEntryQueue(1),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  for (final selected in LiveOrderPeg.values) {
    for (final buy in [true, false]) {
      formTest(
        'BBO $selected side=$buy manual quote reviews fresh limits and freezes matching quantity',
        (tester) async {
          await f.open(tester);
          await peg(tester, selected);
          expect(find.byKey(const Key('live-order-price')), findsNothing);
          await f.field(tester, 'live-order-quantity', '199.000');
          expect(f.capacities.reads, 0);
          await f.tap(tester, 'main-order-review-${buy ? 'buy' : 'sell'}');
          expect(f.capacities.reads, 1);
          final review = f.container.read(mainOrderAllocationProvider).review!;
          final expected = selected.usesAsk(buy) ? '1.97' : '2.01';
          expect(review.intent.draft.quantity, expected);
          expect(review.intent.draft.peg, selected);
          expect(review.intent.draft.buy, buy);
          expect(review.intent.parameters['price'], '0');
          expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
          await f.confirm(tester);
          expect(f.orders.submits, 1);
          expect(f.orders.lastIntent!.draft.quantity, expected);
          expect(f.orders.lastIntent!.draft.peg, selected);
          expect(f.input(tester), '199.000');
        },
      );
    }
  }
  formTest('BBO main review cannot bypass fresh capacity and cancellation preserves manual price', (
    tester,
  ) async {
    await f.open(tester);
    await peg(tester, LiveOrderPeg.queue);
    await f.tap(tester, 'live-order-unit-base');
    await f.field(tester, 'live-order-quantity', '2.000');
    await f.tap(tester, 'live-order-review');
    expect(f.capacities.reads, 1);
    expect(find.byKey(const Key('main-order-frozen-capacity')), findsOneWidget);
    await f.cancel(tester);
    expect(f.input(tester), '2.000');
    await peg(tester, null);
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
      '101',
    );
    expect(f.orders.submits, 0);
  });
  for (final locale in ['en', 'zh']) {
    formTest('BBO $locale capacity rejection preserves exact raw input and can retry', (
      tester,
    ) async {
      await f.open(tester, locale: locale);
      await peg(tester, LiveOrderPeg.counterparty);
      await f.field(tester, 'live-order-quantity', '202.000');
      f.capacities.transform = (context) {
        final raw = capacityAccountPayload();
        (raw['assets'] as List).single['availableBalance'] = '1';
        return assembledCapacity(context: context, payload: raw);
      };
      await f.tap(tester, 'main-order-review-buy');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        f.container.read(mainOrderAllocationProvider).failure!.key,
        'liveCapacityAboveMaximum',
      );
      expect(f.input(tester), '202.000');
      expect(f.orders.submits, 0);
      f.capacities.transform = null;
      await f.tap(tester, 'main-order-review-buy');
      expect(f.capacities.reads, 2);
      await f.cancel(tester);
    });
    for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
      formTest('BBO percentage and frozen review fit $locale $size enlarged text', (tester) async {
        await f.open(tester, locale: locale, size: size, scale: 1.5);
        await peg(tester, LiveOrderPeg.queue);
        await f.tap(tester, 'main-order-capacity-read');
        await f.select(tester, 20);
        final ratioInput = f.input(tester);
        expect(ratioInput, isNotEmpty);
        await f.tap(tester, 'main-order-review-sell');
        final review = f.container.read(mainOrderAllocationProvider).review!;
        expect(review.intent.draft.peg, LiveOrderPeg.queue);
        expect(review.intent.draft.buy, false);
        expect(review.side.quantity.toString(), review.intent.draft.quantity);
        expect(find.text(messages(tester).liveOrderPegHint), findsWidgets);
        await f.cancel(tester);
        expect(tester.takeException(), null);
      });
    }
  }
  formTest('BBO unknown submission disables fresh orders and queries original ID', (tester) async {
    f.orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await f.open(tester);
    await peg(tester, LiveOrderPeg.counterparty);
    await f.field(tester, 'live-order-quantity', '202.000');
    await f.tap(tester, 'main-order-review-buy');
    await f.confirm(tester);
    final intent = f.orders.lastIntent!;
    expect(f.input(tester), '202.000');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('main-order-review-buy'))).onPressed,
      null,
    );
    await f.container.read(liveOrderProvider.notifier).recheck();
    expect(f.orders.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(f.orders.lastIntent!.draft.peg, intent.draft.peg);
    expect(f.orders.submits, 1);
    expect(f.orders.checks, 1);
  });
  formTest('Post Only queue BBO keeps GTX through fresh review', (tester) async {
    await f.open(tester, mode: LiveOrderEntryMode.postOnly);
    await peg(tester, LiveOrderPeg.queue);
    await f.field(tester, 'live-order-quantity', '202.000');
    await f.tap(tester, 'main-order-review-buy');
    await f.confirm(tester);
    expect(f.orders.lastIntent!.parameters['timeInForce'], 'GTX');
    expect(f.orders.lastIntent!.parameters['price'], '0');
    expect(f.orders.lastIntent!.parameters['pegPriceType'], 'QUEUE_1');
  });
}

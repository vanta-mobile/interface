import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/order_confirmation_widget.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_capacity.dart';

void main() {
  late MainOrderLiveFixture f;
  setUp(() => f = MainOrderLiveFixture());
  tearDown(() => f.close());
  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => f.open());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              key: const Key('live-pricing-scroll'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LiveOrderForm(data: f.orders.context, mode: LiveOrderEntryMode.market),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> see(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> input(WidgetTester tester, String text) async {
    await see(tester, 'live-order-quantity');
    await tester.enterText(find.byKey(const Key('live-order-quantity')), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  String raw(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text;

  testWidgets('live market book changes both manual quantities and keeps quote input untouched', (
    tester,
  ) async {
    try {
      await open(tester);
      await input(tester, '198.000');
      await tester.runAsync(() async {
        f.prices(bid: '98', ask: '99');
        await f.flush();
      });
      await tester.pumpAndSettle();
      expect(raw(tester), '198.000');
      await see(tester, 'main-order-review-buy');
      final buy = find.byKey(const Key('main-order-review-buy'));
      final sell = find.byKey(const Key('main-order-review-sell'));
      expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(sell).onPressed, isNotNull);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      final r = f.container.read(mainOrderAllocationProvider).review!;
      expect(r.intent.draft.quantity, '2');
      expect(r.valuation!.context.ask.toString(), '99');
      await tester.runAsync(() async {
        f.prices(bid: '109', ask: '110', mark: '110', last: '110');
        await f.flush();
      });
      await tester.pumpAndSettle();
      expect(r.intent.draft.quantity, '2');
      expect(
        find.descendant(of: find.byType(OrderConfirmationDialog), matching: find.text('1.8 BTC')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('live-order-confirm')));
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      expect(f.orders.lastIntent!.draft.quantity, '1.8');
      expect(raw(tester), '198.000');
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
    'attached PnL conversion follows live entry while raw target and amount stay intact',
    (tester) async {
      try {
        await open(tester);
        await input(tester, '202');
        await see(tester, 'live-order-attached');
        await tester.tap(find.byKey(const Key('live-order-attached')));
        await tester.pumpAndSettle();
        await see(tester, 'attached-tp-enabled');
        await tester.tap(find.byKey(const Key('attached-tp-enabled')));
        await tester.pumpAndSettle();
        await see(tester, 'attached-tp-price');
        await tester.enterText(find.byKey(const Key('attached-tp-price')), '+2');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          f.prices(bid: '100', ask: '102');
          await f.flush();
        });
        await tester.pumpAndSettle();
        await see(tester, 'main-order-review-buy');
        await tester.tap(find.byKey(const Key('main-order-review-buy')));
        await tester.pumpAndSettle();
        final review = f.container.read(mainOrderAllocationProvider).review!;
        expect(review.intent.draft.quantity, '1.98');
        expect(review.intent.draft.attachment!.takeProfit!.price, '103');
        expect(raw(tester), '202');
        expect(
          tester.widget<TextField>(find.byKey(const Key('attached-tp-price'))).controller!.text,
          '+2',
        );
        await tester.runAsync(() async {
          f.prices(bid: '104', ask: '105', mark: '105', last: '105');
          await f.flush();
        });
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(OrderConfirmationDialog),
            matching: find.textContaining('106 USDT'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('live-order-confirm')));
        await tester.pumpAndSettle();
        expect(f.orders.submits, 1);
        expect(f.orders.lastIntent!.draft.quantity, '1.923');
        expect(f.orders.lastIntent!.draft.attachment!.takeProfit!.price, '106');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'expanded quote bootstrap shows loading and can be cancelled without repeat signatures',
    (tester) async {
      try {
        await open(tester);
        await input(tester, '101');
        final originalReads = f.capacities.reads;
        (f.payload['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
        f.quotes['ETHUSDT'] = PricingFeed(
          OrderReferencePrices(symbol: 'ETHUSDT', checkedAt: f.now),
        );
        await see(tester, 'main-order-review-buy');
        await tester.tap(find.byKey(const Key('main-order-review-buy')));
        await tester.pump();
        await tester.runAsync(f.flush);
        await tester.pump(const Duration(milliseconds: 100));
        expect(f.container.read(mainOrderAllocationProvider).preparing, true);
        expect(raw(tester), '101');
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('main-order-capacity-read')))
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byKey(const Key('main-order-capacity-stop')));
        await tester.tap(find.byKey(const Key('main-order-capacity-stop')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          f.prices();
          await f.flush();
        });
        await tester.pumpAndSettle();
        expect(f.container.read(mainOrderAllocationProvider).review, isNull);
        expect(f.container.read(mainOrderAllocationProvider).preparing, false);
        expect(find.byKey(const Key('live-order-confirm')), findsNothing);
        expect(f.capacities.reads, originalReads + 1);
        expect(raw(tester), '101');
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'live percentage refresh and quote failure preserve inputs in $locale enlarged landscape',
      (tester) async {
        try {
          await open(tester, locale: locale, size: const Size(844, 390), scale: 1.5);
          await see(tester, 'main-order-percentage');
          tester.widget<Slider>(find.byKey(const Key('main-order-percentage'))).onChanged!(20);
          await tester.pumpAndSettle();
          final before = raw(tester);
          await tester.runAsync(() async {
            f.prices(bid: '98', ask: '99');
            await f.flush();
          });
          await tester.pumpAndSettle();
          expect(raw(tester), isNot(before));
          final valid = raw(tester);
          await tester.runAsync(() async {
            f.marks.emit(MarkPrices());
            await f.flush();
          });
          await tester.pumpAndSettle();
          expect(raw(tester), valid);
          await see(tester, 'main-order-percentage');
          expect(
            tester.widget<Slider>(find.byKey(const Key('main-order-percentage'))).onChanged,
            isNull,
          );
          await tester.runAsync(() async {
            f.prices(bid: '98', ask: '99');
            await f.flush();
          });
          await tester.pumpAndSettle();
          expect(raw(tester), valid);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }
}

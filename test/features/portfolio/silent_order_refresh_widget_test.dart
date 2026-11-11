import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_capacity.dart';

void main() {
  late MainOrderLiveFixture f;
  setUp(() => f = MainOrderLiveFixture());
  tearDown(() => f.close());

  final quantity = find.byKey(const Key('live-order-quantity'));
  final price = find.byKey(const Key('live-order-price'));
  Finder button(String side) => find.byKey(Key('main-order-review-$side'));
  Finder spinner(String side) =>
      find.descendant(of: button(side), matching: find.byType(CircularProgressIndicator));
  String result(WidgetTester tester, String name) =>
      tester.widget<Text>(find.byKey(Key('main-order-$name-buy'))).textSpan!.toPlainText();

  Future<void> open(
    WidgetTester tester,
    String locale, {
    bool preload = true,
    double width = 430,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    if (preload) {
      await tester.runAsync(f.open);
    } else {
      f.container.read(mainOrderPricingProvider);
      await tester.runAsync(f.flush);
    }
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
              padding: const EdgeInsets.all(16),
              child: Consumer(
                builder: (_, ref, _) =>
                    LiveOrderScreen(symbol: ref.watch(symbolProvider), embedded: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!preload) return;
    await tester.enterText(price, '100');
    await tester.enterText(quantity, '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(f.flush);
    await tester.pump();
  }

  for (final locale in ['en', 'zh']) {
    testWidgets('initial missing trade stays quiet until sizing and clears on recovery: $locale', (
      tester,
    ) async {
      try {
        await open(tester, locale, preload: false);
        f.quotes['BTCUSDT'] = PricingFeed(
          OrderReferencePrices(
            symbol: 'BTCUSDT',
            checkedAt: f.now,
            connection: OrderPriceConnection.online,
            tradeFailed: true,
            tradeFailure: const AccountReadFailure(
              'liveCapacityPriceUnavailable',
              reasonKey: 'livePriceLastStale',
            ),
          ),
        );
        expect(
          await tester.runAsync(
            () => f.container
                .read(mainOrderRefreshProvider.notifier)
                .refresh('BTCUSDT', reconnectPrices: false, background: true),
          ),
          isFalse,
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(quantity));
        expect(find.textContaining(l.livePriceLastStale), findsNothing);
        expect(result(tester, 'liquidation'), '—');
        expect(result(tester, 'cost'), '—');
        expect(find.byKey(const Key('main-order-cost-pending-buy')), findsNothing);
        expect(find.byType(StatusFailureView), findsNothing);
        await tester.enterText(price, '100');
        await tester.enterText(quantity, '10');
        await tester.pump();
        expect(find.textContaining(l.livePriceLastStale), findsWidgets);
        final accountReads = f.orders.reads, capacityReads = f.capacities.reads;
        f.prices();
        await flush(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining(l.livePriceLastStale), findsNothing);
        expect(result(tester, 'cost'), isNot(contains('—')));
        expect(tester.widget<TextField>(quantity).controller!.text, '10');
        expect(f.orders.reads, accountReads);
        expect(f.capacities.reads, capacityReads);
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });

    testWidgets('market switch removes old cancellation but keeps new market failures: $locale', (
      tester,
    ) async {
      try {
        await open(tester, locale);
        f.orders.readFailure = const AccountReadFailure(
          'accountNetwork',
          details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
        );
        expect(
          await f.container.read(mainOrderRefreshProvider.notifier).refresh('BTCUSDT'),
          isFalse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(StatusFailureView), findsNothing);
        expect(quantity, findsOneWidget);
        expect(
          find.textContaining(AppLocalizations.of(tester.element(quantity)).apiRequestCancelled),
          findsWidgets,
        );
        f.container.read(symbolProvider.notifier).select('ETHUSDT');
        await tester.pump();
        expect(find.byType(StatusFailureView), findsNothing);
        expect(find.byKey(const Key('trade-pending-quantity')), findsOneWidget);

        f.orders.readGate = Completer<void>();
        f.orders.readFailure = const AccountReadFailure(
          'accountReadFailed',
          details: ApiErrorDetails(message: 'ETH market read failed', status: 503),
        );
        final replacement = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('ETHUSDT', reconnectPrices: false, background: true);
        await flush(tester);
        expect(find.byType(StatusFailureView), findsNothing);
        f.orders.readGate!.complete();
        expect(await replacement, isFalse);
        await tester.pumpAndSettle();
        expect(find.byType(StatusFailureView), findsOneWidget);
        expect(find.textContaining('ETH market read failed'), findsOneWidget);
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });

    testWidgets('first read keeps fields and loads only missing values: $locale', (tester) async {
      try {
        await open(tester, locale, preload: false, width: 320, scale: 1.5);
        f.orders.readGate = Completer<void>();
        f.capacities.gate = Completer<void>();
        final reading = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false, background: true);
        await flush(tester);
        expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.account);
        expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
        expect(find.byKey(const Key('trade-pending-quantity')), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byKey(const Key('trade-available-pending')), findsOneWidget);
        for (final side in ['buy', 'sell']) {
          for (final name in ['liquidation', 'cost']) {
            final row = find.byKey(Key('trade-pending-$name-$side'));
            expect(find.descendant(of: row, matching: find.byType(SkeletonBox)), findsNothing);
            expect(find.descendant(of: row, matching: find.text('—')), findsOneWidget);
          }
        }
        expect(find.byType(SkeletonBox), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        f.orders.readGate!.complete();
        await flush(tester);
        expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.capacity);
        expect(quantity, findsOneWidget);
        expect(price, findsOneWidget);
        expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
        expect(find.byKey(const Key('main-order-maximum-pending-buy')), findsOneWidget);
        expect(find.byKey(const Key('main-order-liquidation-pending-buy')), findsNothing);
        expect(find.byKey(const Key('main-order-cost-pending-buy')), findsNothing);
        expect(result(tester, 'liquidation'), '—');
        expect(result(tester, 'cost'), '—');
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.enterText(price, '100');
        await tester.enterText(quantity, '10');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.byKey(const Key('main-order-liquidation-pending-buy')), findsOneWidget);
        expect(find.byKey(const Key('main-order-cost-pending-buy')), findsOneWidget);
        f.capacities.gate!.complete();
        await flush(tester);
        expect(await reading, isTrue);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(quantity).controller!.text, '10');
        expect(find.byType(SkeletonBox), findsNothing);
        expect(result(tester, 'cost'), isNot(contains('—')));
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }

  for (final locale in ['en', 'zh']) {
    testWidgets('renewal preserves form and estimates; edits load only affected results: $locale', (
      tester,
    ) async {
      try {
        await open(tester, locale);
        final previousCost = result(tester, 'cost');
        final previousMaximum = result(tester, 'maximum');
        expect(previousCost, isNot(contains('—')));
        f.now = f.now.add(const Duration(seconds: 3));
        f.orders.context = capacityContext(time: f.now);
        f.orders.readGate = Completer<void>();
        f.capacities.gate = Completer<void>();
        final renewing = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false, background: true);
        await flush(tester);
        expect(f.container.read(mainOrderRefreshProvider).background, isTrue);
        expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.widget<TextField>(quantity).enabled, isNot(false));
        expect(tester.widget<TextField>(price).enabled, isNot(false));
        expect(result(tester, 'cost'), previousCost);
        expect(result(tester, 'maximum'), previousMaximum);
        expect(tester.widget<FilledButton>(button('buy')).onPressed, isNotNull);
        expect(tester.widget<FilledButton>(button('sell')).onPressed, isNotNull);

        await tester.enterText(quantity, '20');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(f.container.read(mainOrderAllocationProvider).percent, isNull);
        expect(find.byKey(const Key('main-order-cost-pending-buy')), findsOneWidget);
        expect(find.byKey(const Key('main-order-cost-pending-sell')), findsOneWidget);
        expect(find.byKey(const Key('main-order-maximum-pending-buy')), findsNothing);
        expect(result(tester, 'maximum'), previousMaximum);
        expect(spinner('buy'), findsNothing);
        expect(spinner('sell'), findsNothing);
        expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);

        f.orders.readGate!.complete();
        await flush(tester);
        expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.capacity);
        // The new account anchor retains the old scope while capacity renews.
        expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
        expect(tester.widget<TextField>(quantity).controller!.text, '20');
        expect(tester.widget<TextField>(quantity).enabled, isNot(false));
        f.capacities.gate!.complete();
        await flush(tester);
        expect(await renewing, isTrue);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('main-order-cost-pending-buy')), findsNothing);
        expect(result(tester, 'cost'), isNot(previousCost));
        expect(tester.widget<FilledButton>(button('buy')).onPressed, isNotNull);
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }

  testWidgets('quote gaps retain values; edited sizes show only right-hand value placeholders', (
    tester,
  ) async {
    try {
      await open(tester, 'en');
      final before = result(tester, 'cost');
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      final accountReads = f.orders.reads, capacityReads = f.capacities.reads;
      f.quotes['BTCUSDT']!.emit(
        OrderReferencePrices(
          symbol: 'BTCUSDT',
          checkedAt: f.now,
          connection: OrderPriceConnection.connecting,
        ),
      );
      await flush(tester);
      expect(result(tester, 'cost'), before);
      await tester.enterText(quantity, '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final pending = find.byKey(const Key('main-order-liquidation-pending-buy'));
      expect(pending, findsOneWidget);
      final skeleton = find.descendant(of: pending, matching: find.byType(SkeletonBox));
      expect(tester.getSize(skeleton).width, 72);
      expect(tester.getRect(skeleton).right, closeTo(tester.getRect(pending).right, .01));
      expect(find.text(l.tradeEstimatedLiquidation), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
      f.prices();
      await flush(tester);
      await tester.pumpAndSettle();
      expect(pending, findsNothing);
      expect(result(tester, 'cost'), isNot(before));
      expect(f.orders.reads, accountReads);
      expect(f.capacities.reads, capacityReads);
      // A further input edit resolves on the next frame, without an API read.
      await tester.enterText(quantity, '30');
      await tester.pump();
      expect(result(tester, 'cost'), isNot(contains('—')));
      expect(f.orders.reads, accountReads);
      expect(f.capacities.reads, capacityReads);
      expect(f.orders.submits, 0);
      // Clearing a previously populated draft removes its estimates even
      // while the quote is reconnecting, without starting an account read.
      f.quotes['BTCUSDT']!.emit(
        OrderReferencePrices(
          symbol: 'BTCUSDT',
          checkedAt: f.now,
          connection: OrderPriceConnection.connecting,
        ),
      );
      await flush(tester);
      for (final text in ['', '0']) {
        await tester.enterText(quantity, text);
        await tester.pump();
        for (final side in ['buy', 'sell']) {
          for (final name in ['liquidation', 'cost']) {
            expect(find.byKey(Key('main-order-$name-pending-$side')), findsNothing);
            expect(
              tester
                  .widget<Text>(find.byKey(Key('main-order-$name-$side')))
                  .textSpan!
                  .toPlainText(),
              '—',
            );
          }
        }
      }
      expect(f.orders.reads, accountReads);
      expect(f.capacities.reads, capacityReads);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });

  testWidgets('unchanged estimates survive replacement of the account anchor', (tester) async {
    try {
      await open(tester, 'en');
      final previousCost = result(tester, 'cost');
      f.now = f.now.add(const Duration(seconds: 3));
      f.orders.context = capacityContext(time: f.now);
      f.capacities.gate = Completer<void>();
      final renewing = f.container
          .read(mainOrderRefreshProvider.notifier)
          .refresh('BTCUSDT', reconnectPrices: false, background: true);
      await flush(tester);
      expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.capacity);
      expect(f.container.read(mainOrderRefreshProvider).showProgress, isFalse);
      expect(result(tester, 'cost'), previousCost);
      expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      f.capacities.gate!.complete();
      await flush(tester);
      expect(await renewing, isTrue);
      expect(result(tester, 'cost'), previousCost);
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });

  testWidgets('an explicit direction click shows progress while refreshing expired facts', (
    tester,
  ) async {
    try {
      await open(tester, 'en');
      f.container.read(liveOrderProvider.notifier).markStale();
      await tester.pumpAndSettle();
      f.orders.readGate = Completer<void>();
      await tester.ensureVisible(button('buy'));
      await tester.tap(button('buy'));
      await flush(tester);
      expect(f.container.read(mainOrderRefreshProvider).showProgress, isTrue);
      expect(spinner('buy'), findsOneWidget);
      expect(spinner('sell'), findsNothing);
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      f.orders.readGate!.complete();
      await flush(tester);
      await tester.pumpAndSettle();
      expect(spinner('buy'), findsNothing);
      expect(f.orders.submits, 0);
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });

  testWidgets('only clicked direction shows loading during submit preparation', (tester) async {
    try {
      await open(tester, 'en');
      f.capacities.gate = Completer<void>();
      await tester.ensureVisible(button('sell'));
      await tester.tap(button('sell'));
      await flush(tester);
      expect(f.container.read(mainOrderAllocationProvider).preparing, isTrue);
      expect(spinner('sell'), findsOneWidget);
      expect(spinner('buy'), findsNothing);
      expect(tester.widget<FilledButton>(button('buy')).onPressed, isNull);
      expect(tester.widget<FilledButton>(button('sell')).onPressed, isNull);
      expect(find.byKey(const Key('trade-order-skeleton')), findsNothing);
      expect(f.capacities.reads, 2);
      f.container.read(mainOrderAllocationProvider.notifier).stop();
      f.capacities.gate!.complete();
      await flush(tester);
      await tester.pumpAndSettle();
      expect(f.orders.submits, 0);
      expect(spinner('sell'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
}

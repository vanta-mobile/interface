import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';

void main() {
  late MainOrderLiveFixture f;
  setUp(() => f = MainOrderLiveFixture());
  tearDown(() => f.close());
  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(430, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const LiveOrderScreen(symbol: 'BTCUSDT'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> see(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: scroll);
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester) async {
    await see(tester, 'live-order-quantity');
    await tester.enterText(find.byKey(const Key('live-order-quantity')), '202.000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  String raw(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text;
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'full account read shows cancellable disabled button and preserves raw input in $locale',
      (tester) async {
        try {
          await open(tester, locale: locale, size: const Size(844, 390));
          await enter(tester);
          await see(tester, 'live-order-read');
          f.orders.readGate = Completer<void>();
          await tester.tap(find.byKey(const Key('live-order-read')));
          await tester.pump();
          expect(
            tester.widget<FilledButton>(find.byKey(const Key('live-order-read'))).onPressed,
            isNull,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('live-order-read')),
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
          expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.account);
          await tester.ensureVisible(find.byKey(const Key('live-order-read-stop')));
          await tester.tap(find.byKey(const Key('live-order-read-stop')));
          await tester.pumpAndSettle();
          f.orders.readGate!.complete();
          await tester.runAsync(f.flush);
          await tester.pumpAndSettle();
          expect(f.capacities.reads, 1);
          expect(raw(tester), '202.000');
          expect(f.orders.submits, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          f.disposeContainer();
        }
      },
    );
  }
  testWidgets(
    'pull refresh awaits both signed stages and public pricing before closing indicator',
    (tester) async {
      try {
        await open(tester);
        await enter(tester);
        await see(tester, 'live-order-read');
        f.capacities.gate = Completer<void>();
        var finished = false;
        final refreshing = tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show()
            .then((_) {
              finished = true;
            });
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(f.flush);
        await tester.pump();
        expect(f.container.read(mainOrderRefreshProvider).stage, MainOrderRefreshStage.capacity);
        expect(f.orders.reads, 2);
        expect(f.capacities.reads, 2);
        expect(finished, false);
        f.capacities.gate!.complete();
        await tester.pump();
        await tester.runAsync(f.flush);
        await tester.pumpAndSettle();
        await refreshing;
        expect(finished, true);
        expect(f.container.read(mainOrderRefreshProvider).failure, isNull);
        expect(raw(tester), '202.000');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    },
  );
  testWidgets('failed full refresh keeps input, exposes safe reason and allows retry', (
    tester,
  ) async {
    try {
      await open(tester, locale: 'zh', size: const Size(320, 844));
      await enter(tester);
      await see(tester, 'live-order-read');
      f.capacities.failure = const AccountReadFailure('authWalletRejected');
      await tester.tap(find.byKey(const Key('live-order-read')));
      await tester.pump();
      await tester.runAsync(f.flush);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-refresh-error')), findsOneWidget);
      expect(raw(tester), '202.000');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-read'))).onPressed,
        isNotNull,
      );
      f.capacities.failure = null;
      await tester.tap(find.byKey(const Key('live-order-read')));
      await tester.pump();
      await tester.runAsync(f.flush);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-order-refresh-error')), findsNothing);
      expect(f.capacities.reads, 3);
      expect(raw(tester), '202.000');
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
  for (final locale in ['en', 'zh']) {
    testWidgets('form preserves the actual price API failure in $locale', (tester) async {
      try {
        await open(tester, locale: locale);
        await enter(tester);
        final old = f.quotes['BTCUSDT']!.value;
        f.quotes['BTCUSDT']!.emit(
          OrderReferencePrices(
            symbol: old.symbol,
            checkedAt: f.now,
            connection: OrderPriceConnection.online,
            tradeFailed: true,
            tradeFailure: const AccountReadFailure(
              'liveCapacityPriceUnavailable',
              reasonKey: 'livePriceLastMissing',
              details: ApiErrorDetails(message: 'Price feed temporarily unavailable', status: 503),
            ),
          ),
        );
        await tester.runAsync(f.flush);
        await tester.pumpAndSettle();
        expect(find.textContaining('Price feed temporarily unavailable'), findsWidgets);
        final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
        expect(find.text(l.liveCapacityPriceUnavailable), findsNothing);
        expect(raw(tester), '202.000');
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('live-order-quantity')))
              .decoration!
              .hintText,
          isNull,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }
  testWidgets('account invalidation retains its own cause instead of a price error', (
    tester,
  ) async {
    try {
      await open(tester);
      await enter(tester);
      f.container.read(liveOrderProvider.notifier).markStale();
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      expect(find.text(l.liveOrderContextExpired), findsWidgets);
      expect(find.text(l.liveCapacityPriceUnavailable), findsNothing);
      expect(raw(tester), '202.000');
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
}

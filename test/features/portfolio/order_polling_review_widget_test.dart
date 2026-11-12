import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/order_review_activity_provider.dart';
import 'package:vanta/core/presentation/status_view.dart';
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
    testWidgets('confirmation renews an expired account and submits current terms: $locale', (
      tester,
    ) async {
      try {
        await open(tester, locale);
        await tester.ensureVisible(button('buy'));
        await tester.tap(button('buy'));
        await flush(tester);
        await tester.pumpAndSettle();
        final confirm = find.byKey(const Key('live-order-confirm'));
        final confirmButton = find.descendant(of: confirm, matching: find.byType(FilledButton));
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const Key('order-confirm-direction'))).right,
          closeTo(tester.getRect(find.byKey(const Key('order-confirm-quantity'))).right, .01),
        );
        f.now = f.now.add(const Duration(seconds: 31));
        f.orders.context = capacityContext(time: f.now);
        f.orders.readGate = Completer<void>();
        f.prices();
        final renewal = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false, background: true);
        await flush(tester);
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
        await tester.tap(confirm);
        await tester.pump();
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
        expect(
          find.descendant(of: confirm, matching: find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );
        await tester.tap(confirm);
        await tester.pump();
        expect(f.orders.submits, 0);
        f.orders.submitGate = Completer<void>();
        f.orders.readGate!.complete();
        expect(await renewal, isTrue);
        await flush(tester);
        final signing = tester.widget<OrderConfirmationDialog>(
          find.byType(OrderConfirmationDialog),
        );
        expect(signing.intent, same(f.orders.lastIntent));
        expect(signing.intent.context.receivedAt, f.now);
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
        f.orders.submitGate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(OrderConfirmationDialog), findsNothing);
        expect(f.orders.submits, 1);
        expect(f.orders.lastIntent!.context.receivedAt, f.now);
        expect(f.orders.lastIntent!.draft.quantity, '0.1');
        final l10n = AppLocalizations.of(tester.element(quantity));
        expect(find.textContaining(l10n.liveAllocationChanged), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }

  testWidgets('open confirmation follows background renewal and remains until explicit cancel', (
    tester,
  ) async {
    try {
      await open(tester, 'zh');
      await tester.ensureVisible(button('buy'));
      await tester.tap(button('buy'));
      await flush(tester);
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      expect(f.container.read(orderReviewActivityProvider), 1);
      final context = f.container.read(liveOrderProvider).context;
      final accountReads = f.orders.reads, capacityReads = f.capacities.reads;
      expect(
        await f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false),
        isFalse,
      );
      await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
      await f.container.read(mainOrderCapacityProvider.notifier).load('BTCUSDT');
      expect(f.orders.reads, accountReads);
      expect(f.capacities.reads, capacityReads);
      expect(f.container.read(liveOrderProvider).context, same(context));
      // An unrelated touch must not dismiss a financial confirmation.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        f.now = f.now.add(const Duration(seconds: 5));
        f.prices();
        if (i == 2 || i == 5) {
          f.orders.context = capacityContext(time: f.now);
          expect(
            await f.container
                .read(mainOrderRefreshProvider.notifier)
                .refresh('BTCUSDT', reconnectPrices: false, background: true),
            isTrue,
          );
        }
        await flush(tester);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      }
      expect(f.orders.submits, 0);
      expect(f.container.read(orderReviewActivityProvider), 1);
      await tester.tap(find.byKey(const Key('live-order-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsNothing);
      expect(f.container.read(orderReviewActivityProvider), 0);
      expect(tester.widget<TextField>(quantity).controller!.text, '10');
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });

  testWidgets(
    'failed pre-confirmation read keeps draft and reports endpoint; explicit retry reviews',
    (tester) async {
      try {
        await open(tester, 'zh');
        f.capacities.failure = const AccountReadFailure(
          'accountDataInvalid',
          details: ApiErrorDetails(
            cause: ApiErrorCause.invalidResponse,
            endpoint: '/fapi/v3/commissionRate',
          ),
        );
        await tester.ensureVisible(button('buy'));
        await tester.tap(button('buy'));
        await flush(tester);
        await tester.pumpAndSettle();
        expect(find.byType(OrderConfirmationDialog), findsNothing);
        expect(find.byType(StatusFailureView), findsNothing);
        expect(find.textContaining('/fapi/v3/commissionRate'), findsWidgets);
        expect(tester.widget<TextField>(quantity).controller!.text, '10');
        expect(f.orders.submits, 0);
        f.capacities.failure = null;
        await tester.ensureVisible(button('buy'));
        await tester.tap(button('buy'));
        await flush(tester);
        await tester.pumpAndSettle();
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(f.orders.submits, 0);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    },
  );

  for (final stage in [MainOrderRefreshStage.account, MainOrderRefreshStage.capacity]) {
    testWidgets('failed background $stage keeps inputs, values and retryable direction actions', (
      tester,
    ) async {
      try {
        await open(tester, 'zh');
        final beforeCost = result(tester, 'cost'), beforeMax = result(tester, 'maximum');
        const failure = AccountReadFailure(
          'accountDataInvalid',
          details: ApiErrorDetails(
            cause: ApiErrorCause.invalidResponse,
            endpoint: '/fapi/v3/commissionRate',
          ),
        );
        if (stage == MainOrderRefreshStage.account) f.orders.readFailure = failure;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.failure = failure;
        expect(
          await f.container
              .read(mainOrderRefreshProvider.notifier)
              .refresh('BTCUSDT', reconnectPrices: false, background: true),
          isFalse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(StatusFailureView), findsNothing);
        expect(tester.widget<TextField>(quantity).controller!.text, '10');
        expect(result(tester, 'cost'), beforeCost);
        expect(result(tester, 'maximum'), beforeMax);
        // Background failures stay silent until a direction click needs them.
        expect(find.textContaining('/fapi/v3/commissionRate'), findsNothing);
        for (final side in ['buy', 'sell']) {
          expect(tester.widget<FilledButton>(button(side)).onPressed, isNotNull);
          expect(spinner(side), findsNothing);
        }
        f.orders.readFailure = null;
        f.capacities.failure = null;
        expect(
          await f.container
              .read(mainOrderRefreshProvider.notifier)
              .refresh('BTCUSDT', reconnectPrices: false, background: true),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('/fapi/v3/commissionRate'), findsNothing);
        expect(f.orders.submits, 0);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });

    testWidgets('direction click takes over silent $stage and reaches confirmation once', (
      tester,
    ) async {
      try {
        await open(tester, 'en');
        final oldGate = Completer<void>();
        if (stage == MainOrderRefreshStage.account) f.orders.readGate = oldGate;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = oldGate;
        final polling = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false, background: true);
        await flush(tester);
        expect(f.container.read(mainOrderRefreshProvider).stage, stage);
        final explicitGate = f.orders.readGate = Completer<void>();
        f.capacities.gate = null;
        await tester.ensureVisible(button('buy'));
        await tester.tap(button('buy'));
        await flush(tester);
        expect(await polling, isFalse);
        expect(spinner('buy'), findsOneWidget);
        expect(spinner('sell'), findsNothing);
        for (final side in ['buy', 'sell']) {
          expect(tester.widget<FilledButton>(button(side)).onPressed, isNull);
        }
        oldGate.complete();
        await flush(tester);
        explicitGate.complete();
        await flush(tester);
        await tester.pumpAndSettle();
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(tester.widget<TextField>(quantity).controller!.text, '10');
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }
  testWidgets('slider drags continuously in whole units; only its end is the maximum', (
    tester,
  ) async {
    try {
      await open(tester, 'en');
      final key = find.byKey(const Key('main-order-percentage'));
      Slider slider() => tester.widget<Slider>(key);
      String text() => tester.widget<TextField>(quantity).controller!.text;
      expect(slider().divisions, isNull);
      await tester.ensureVisible(key);
      var last = 0;
      for (final position in [0.37, 0.731]) {
        slider().onChanged!(position);
        slider().onChangeEnd!(position);
        await tester.pumpAndSettle();
        expect(f.container.read(mainOrderAllocationProvider).percent, isNull);
        expect(text(), matches(RegExp(r'^[1-9][0-9]*$')));
        expect(slider().value, inInclusiveRange(position - 0.01, position));
        last = int.parse(text());
      }
      slider().onChanged!(1);
      slider().onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(f.container.read(mainOrderAllocationProvider).percent, 100);
      expect(slider().value, 1);
      expect(double.parse(text()), greaterThan(last));
      slider().onChanged!(0);
      slider().onChangeEnd!(0);
      await tester.pumpAndSettle();
      expect(f.container.read(mainOrderAllocationProvider).percent, 0);
      expect(text(), '');
      expect(f.orders.submits, 0);
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
  testWidgets('silent polling neither disables nor interrupts the slider', (tester) async {
    try {
      await open(tester, 'en');
      final key = find.byKey(const Key('main-order-percentage'));
      Slider slider() => tester.widget<Slider>(key);
      String text() => tester.widget<TextField>(quantity).controller!.text;
      await tester.ensureVisible(key);
      final gate = f.orders.readGate = Completer<void>();
      final polling = f.container
          .read(mainOrderRefreshProvider.notifier)
          .refresh('BTCUSDT', reconnectPrices: false, background: true);
      await flush(tester);
      expect(f.container.read(mainOrderRefreshProvider).loading, true);
      expect(slider().onChanged, isNotNull);
      slider().onChanged!(0.4);
      await tester.pump();
      expect(slider().value, 0.4);
      slider().onChangeEnd!(0.4);
      await tester.pump();
      expect(text(), matches(RegExp(r'^[1-9][0-9]*$')));
      gate.complete();
      expect(await polling, isTrue);
      await flush(tester);
      await tester.pumpAndSettle();
      expect(slider().onChanged, isNotNull);
      expect(text(), matches(RegExp(r'^[1-9][0-9]*$')));
      expect(f.orders.submits, 0);
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
  testWidgets('a failed direction click reports its cause until the form changes', (tester) async {
    try {
      await open(tester, 'en');
      final gate = f.orders.readGate = Completer<void>();
      final polling = f.container
          .read(mainOrderRefreshProvider.notifier)
          .refresh('BTCUSDT', reconnectPrices: false, background: true);
      await flush(tester);
      f.orders.readGate = null;
      f.orders.readFailure = const AccountReadFailure(
        'accountDataInvalid',
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: '/fapi/v3/commissionRate',
        ),
      );
      await tester.ensureVisible(button('buy'));
      await tester.tap(button('buy'));
      await flush(tester);
      gate.complete();
      expect(await polling, isFalse);
      await flush(tester);
      await tester.pumpAndSettle();
      final failure = find.byKey(const Key('main-order-review-failure'));
      expect(failure, findsOneWidget);
      expect(tester.widget<Text>(failure).data, contains('/fapi/v3/commissionRate'));
      expect(find.byType(OrderConfirmationDialog), findsNothing);
      await tester.enterText(quantity, '11');
      await tester.pump();
      expect(failure, findsNothing);
      expect(f.orders.submits, 0);
    } finally {
      f.container.read(mainOrderRefreshProvider.notifier).stop();
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
}

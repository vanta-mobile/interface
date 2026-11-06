import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/features/portfolio/presentation/main_order_capacity_panel.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late TestCapacityRepository repository;
  late ValueNotifier<String> input;
  var disposed = false;
  setUp(() {
    disposed = false;
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = capacityContext();
    repository = TestCapacityRepository();
    input = ValueNotifier('');
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderPricingProvider.overrideWith(fixtureBoundedPricing),
        mainOrderCapacityRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => liveOrderClock),
      ],
    );
  });
  tearDown(() async {
    if (!disposed) container.dispose();
    input.dispose();
    await identity.dispose();
  });
  void panelTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        disposed = true;
      }
    });
  }

  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(430, 900),
    double scale = 1,
    LiveOrderDraft? draft,
    bool form = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(authProvider);
    await tester.pump();
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: form
                    ? LiveOrderForm(data: orders.context)
                    : ValueListenableBuilder<String>(
                        valueListenable: input,
                        builder: (context, value, _) => MainOrderCapacityPanel(
                          data: orders.context,
                          draft: draft ?? liveDraft(price: '101'),
                          unit: OrderSizeUnit.base,
                          input: value,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.scrollUntilVisible(target, 180, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder inKey(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(MainOrderCapacityPanel)));

  panelTest('mount is read-free; explicit read displays independent maxima and blank costs', (
    tester,
  ) async {
    await open(tester);
    expect(repository.reads, 0);
    expect(inKey('main-order-maximum-buy', '—'), findsOneWidget);
    expect(inKey('main-order-maximum-sell', '—'), findsOneWidget);
    await tap(tester, 'main-order-capacity-read');
    expect(repository.reads, 1);
    expect(inKey('main-order-maximum-buy', '9.009 BTC'), findsOneWidget);
    expect(inKey('main-order-maximum-sell', '9.9 BTC'), findsOneWidget);
    expect(inKey('main-order-cost-buy', '—'), findsOneWidget);
    expect(inKey('main-order-cost-sell', '—'), findsOneWidget);
    expect(orders.submits, 0);
  });
  panelTest('editing input recomputes two costs without another signature or changing input', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'main-order-capacity-read');
    input.value = '2.000';
    await tester.pumpAndSettle();
    expect(inKey('main-order-cost-buy', '≈ 22.2 USDT'), findsOneWidget);
    expect(inKey('main-order-cost-sell', '≈ 20.2 USDT'), findsOneWidget);
    input.value = 'invalid';
    await tester.pumpAndSettle();
    expect(inKey('main-order-cost-buy', '—'), findsOneWidget);
    expect(input.value, 'invalid');
    expect(repository.reads, 1);
    expect(orders.submits, 0);
  });
  panelTest(
    'failed refresh removes actionable values, preserves input, and supports explicit retry',
    (tester) async {
      input.value = '2';
      await open(tester);
      await tap(tester, 'main-order-capacity-read');
      repository.failure = const AccountReadFailure('accountNetwork');
      await tap(tester, 'main-order-capacity-read');
      expect(inKey('main-order-maximum-buy', '—'), findsOneWidget);
      expect(inKey('main-order-cost-buy', '—'), findsOneWidget);
      expect(find.text(messages(tester).accountNetwork), findsOneWidget);
      expect(find.text(messages(tester).liveCapacityStale), findsOneWidget);
      expect(input.value, '2');
      repository.failure = null;
      await tap(tester, 'main-order-capacity-read');
      expect(inKey('main-order-cost-buy', '≈ 22.2 USDT'), findsOneWidget);
      expect(repository.reads, 3);
    },
  );
  panelTest('known zero capacity differs from unknown and never creates a zero-quantity cost', (
    tester,
  ) async {
    repository.transform = (context) => assembledCapacity(
      context: context,
      contractCap: SymbolOpenableNotional(
        symbol: context.symbol,
        leverage: context.leverage,
        receivedAt: liveOrderClock,
        remaining: Decimal.zero,
      ),
    );
    await open(tester);
    await tap(tester, 'main-order-capacity-read');
    expect(inKey('main-order-maximum-buy', '0 BTC'), findsOneWidget);
    expect(inKey('main-order-cost-buy', '—'), findsOneWidget);
  });
  panelTest('cancelled read cannot display a late response or place an order', (tester) async {
    repository.gate = Completer<void>();
    await open(tester);
    await tester.tap(find.byKey(const Key('main-order-capacity-read')));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('main-order-capacity-stop')));
    await tester.tap(find.byKey(const Key('main-order-capacity-stop')));
    await tester.pumpAndSettle();
    expect(repository.latestCurrent!(), false);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(inKey('main-order-maximum-buy', '—'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(orders.submits, 0);
  });
  panelTest('account invalidation and deadline hide values and disable reads until base refresh', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'main-order-capacity-read');
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(inKey('main-order-maximum-buy', '—'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('main-order-capacity-read'))).onPressed,
      null,
    );
    expect(find.text(messages(tester).liveCapacityStale), findsOneWidget);
    expect(repository.reads, 1);
  });
  panelTest('other settings disable reads without requesting new signatures', (tester) async {
    await open(tester);
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('main-order-capacity-read'))).onPressed,
      null,
    );
    expect(repository.reads, 0);
    activity.finish(lease, unresolved: false);
  });
  panelTest('changing symbols hides previous capacity without a new request', (tester) async {
    await open(tester);
    await tap(tester, 'main-order-capacity-read');
    container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    expect(inKey('main-order-maximum-buy', '—'), findsOneWidget);
    expect(repository.reads, 1);
  });
  panelTest('ordinary queue BBO displays independent nonzero book capacities', (tester) async {
    await open(
      tester,
      draft: liveDraft(price: '', peg: LiveOrderPeg.queue),
    );
    await tap(tester, 'main-order-capacity-read');
    expect(inKey('main-order-maximum-buy', '10.101 BTC'), findsOneWidget);
    expect(inKey('main-order-maximum-sell', '9.9 BTC'), findsOneWidget);
    expect(find.text(messages(tester).liveCapacityPriceUnavailable), findsNothing);
  });
  panelTest('production form exposes explicit capacity read and preserves manual inputs', (
    tester,
  ) async {
    await open(tester, form: true);
    await tester.enterText(find.byKey(const Key('live-order-quantity')), '200.000');
    await tester.enterText(find.byKey(const Key('live-order-price')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tap(tester, 'main-order-capacity-read');
    expect(repository.reads, 1);
    expect(inKey('main-order-cost-buy', '≈ 20 USDT'), findsOneWidget);
    expect(inKey('main-order-cost-sell', '≈ 20 USDT'), findsOneWidget);
    final text = tester
        .widget<TextField>(find.byKey(const Key('live-order-quantity')))
        .controller!
        .text;
    expect(text, '200.000');
    expect(orders.submits, 0);
  });
  for (final locale in ['en', 'zh']) {
    for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
      panelTest('dual references render at enlarged text $locale $size', (tester) async {
        input.value = '2';
        await open(tester, locale: locale, size: size, scale: 1.5);
        await tap(tester, 'main-order-capacity-read');
        expect(find.text(messages(tester).liveCapacityTitle), findsOneWidget);
        expect(inKey('main-order-maximum-buy', '9.009 BTC'), findsOneWidget);
        expect(inKey('main-order-cost-sell', '≈ 20.2 USDT'), findsOneWidget);
        expect(tester.takeException(), null);
      });
    }
  }
}

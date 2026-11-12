import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:flutter/material.dart';

import 'order_confirmation_widget.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/order_confirmation_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'aster_account.dart';
import 'identity_repository.dart';
import 'live_order.dart';
import 'main_order_capacity.dart';
import 'quick_order.dart';

/// Shared production-form fixture for percentage and manual-sizing scenarios.
/// All account, capacity and order requests remain synthetic.
class MainOrderFormFixture {
  late final ProviderContainer container;
  late final TestIdentityRepository identity;
  late final TestLiveOrderRepository orders;
  late final TestCapacityRepository capacities;
  late final MemoryOrderConfirmationPreferences preferences;
  DateTime now = liveOrderClock;
  bool _disposed = false;

  MainOrderFormFixture() {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = capacityContext();
    capacities = TestCapacityRepository();
    preferences = MemoryOrderConfirmationPreferences();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderPricingProvider.overrideWith(fixtureBoundedPricing),
        mainOrderCapacityRepositoryProvider.overrideWithValue(capacities),
        orderConfirmationPreferencesProvider.overrideWithValue(preferences),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    _disposeContainer();
  }

  void _disposeContainer() {
    if (_disposed) return;
    container.dispose();
    _disposed = true;
  }

  Future<void> close() async {
    _disposeContainer();
    await identity.dispose();
  }

  Future<void> visible(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(
          of: find.byKey(const Key('allocation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 150, scrollable: scroll);
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, [int percent = 20]) async {
    await visible(tester, 'main-order-percentage');
    final slider = tester.widget<Slider>(find.byKey(const Key('main-order-percentage')));
    slider.onChanged!(percent.toDouble());
    slider.onChangeEnd!(percent.toDouble());
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(430, 900),
    double scale = 1,
    LiveOrderEntryMode mode = LiveOrderEntryMode.limit,
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
              key: const Key('allocation-scroll'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LiveOrderForm(data: orders.context, mode: mode),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (mode == LiveOrderEntryMode.limit) await field(tester, 'live-order-price', '101');
  }

  String input(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text;
  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('live-order-confirm')));
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    await dismissOrderConfirmation(tester);
  }

  Future<void> cancel(WidgetTester tester) async {
    final l10n = AppLocalizations.of(tester.element(find.byType(OrderConfirmationDialog)));
    await tester.tap(
      find.descendant(of: find.byType(OrderConfirmationDialog), matching: find.text(l10n.cancel)),
    );
    await tester.pumpAndSettle();
  }
}

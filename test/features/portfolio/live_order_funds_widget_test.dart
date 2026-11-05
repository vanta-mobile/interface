import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/trade_fixture.dart';

import '../../support/live_order_widget.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final scrollable = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    if (['live-order-read', 'live-order-collateral', 'live-order-available'].contains(key)) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLiveOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  Future<void> fill(WidgetTester tester, {String quantity = '0.001'}) async {
    await visible(tester, 'live-order-quantity');
    await selectLiveBase(tester);
    await tester.enterText(find.byKey(const Key('live-order-quantity')), quantity);
    await visible(tester, 'live-order-price');
    await tester.enterText(find.byKey(const Key('live-order-price')), '80000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('opening shows exact available funds and live estimate in form and confirmation', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await visible(tester, 'live-order-available');
    expect(find.text('89.000000000000000001 USDT'), findsOneWidget);
    expect(find.text('100.000000000000000001 USDT'), findsNothing);
    await fill(tester);
    await visible(tester, 'live-order-opening-margin');
    expect(
      find.descendant(
        of: find.byKey(const Key('live-order-opening-margin')),
        matching: find.text('8 USDT'),
      ),
      findsOneWidget,
    );
    await tap(tester, 'live-order-review');
    final dialog = find.byType(AlertDialog);
    for (final text in ['89.000000000000000001 USDT', '8 USDT', '0.001 BTC', 'Single-asset']) {
      expect(
        find.descendant(of: dialog, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.submits, 0);
    expect(identity.wallets, 0);
    await dispose(tester, container);
  });
  testWidgets('partial fund failure disables opening and refresh preserves order input', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository()
      ..context = liveContext(
        withFunds: false,
        fundsFailure: const AccountReadFailure('authWalletRejected'),
      );
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await fill(tester);
    await visible(tester, 'live-order-review');
    expect(tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed, null);
    repository.context = liveContext();
    await tap(tester, 'live-order-read');
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
      '0.001',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
      '80000',
    );
    await visible(tester, 'live-order-review');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
      isNotNull,
    );
    expect(repository.submits, 0);
    await dispose(tester, container);
  });
  testWidgets(
    'multi-asset available amounts retain units and unknown eligibility without summing',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()
        ..context = liveContext(
          assetMode: FuturesAssetMode.multi,
          fundsPayload: {
            ...accountPayload(),
            'positions': <Map<String, dynamic>>[],
            'canTrade': true,
            'availableBalance': '-1.000000000000000001',
            'assets': [
              {
                'asset': 'USDT',
                'walletBalance': '100',
                'availableBalance': '-1.000000000000000001',
                'marginAvailable': true,
              },
              {
                'asset': 'ASBNB',
                'walletBalance': '2',
                'availableBalance': '0.000000000000000123',
                'marginAvailable': true,
              },
              {'asset': 'BNB', 'walletBalance': '3'},
              {
                'asset': 'OTHER',
                'walletBalance': '4',
                'availableBalance': '1',
                'marginAvailable': false,
              },
            ],
          },
        );
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await tap(tester, 'live-order-collateral');
      expect(find.text('0.000000000000000123 ASBNB'), findsOneWidget);
      expect(find.text('Collateral eligibility not provided'), findsOneWidget);
      expect(find.text('Not eligible as collateral in Multi-Assets mode'), findsOneWidget);
      expect(find.text('Multi-assets'), findsOneWidget);
      expect(tester.takeException(), null);
      await dispose(tester, container);
    },
  );
  testWidgets(
    'missing balance stays unknown; zero balance remains explicit and estimate is advisory',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()..context = liveContext(available: null);
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await visible(tester, 'live-order-available');
      expect(
        find.descendant(
          of: find.byKey(const Key('live-order-available')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      repository.context = liveContext(available: '0');
      await tap(tester, 'live-order-read');
      await fill(tester);
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        isNotNull,
      );
      expect(find.textContaining('estimate exceeds'), findsOneWidget);
      container.read(liveOrderProvider.notifier).markStale();
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      await visible(tester, 'live-order-available');
      expect(find.text('0 USDT'), findsOneWidget);
      expect(
        find.text('Historical funds snapshot. Refresh before reviewing another opening order.'),
        findsOneWidget,
      );
      await dispose(tester, container);
    },
  );
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'multi-asset funds, estimates and confirmation fit narrow enlarged and landscape $locale',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final repository = TestLiveOrderRepository()
          ..context = liveContext(assetMode: FuturesAssetMode.multi);
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          identityRepository: identity,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
          language: Locale(locale),
        );
        await open(tester, container);
        await tap(tester, 'live-order-collateral');
        await fill(tester);
        await tap(tester, 'live-order-review');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), null);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        expect(repository.submits, 0);
        await dispose(tester, container);
      },
    );
  }
}

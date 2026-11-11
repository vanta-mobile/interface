import '../../support/order_confirmation_widget.dart';
import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/quick_order.dart';
import '../../support/trade_fixture.dart';

import '../../support/live_order_widget.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLiveOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('live-order-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> read(WidgetTester tester) async {
    await visible(tester, 'live-order-read');
    await tester.tap(find.byKey(const Key('live-order-read')));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await visible(tester, 'live-order-quantity');
    await selectLiveBase(tester);
    await tester.enterText(find.byKey(const Key('live-order-quantity')), '0.001');
    await visible(tester, 'live-order-price');
    await tester.enterText(find.byKey(const Key('live-order-price')), '80000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'explicit market confirmation preference is shared, while limit review remains required',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository();
      final preference = MemoryOrderConfirmationPreferences()..required = false;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        orderConfirmationPreferences: preference,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await read(tester);
      await fill(tester);
      await visible(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.submits, 0);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('live-order-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await chooseOrderExecution(tester, true);
      await visible(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsNothing);
      expect(repository.submits, 1);
      expect(repository.lastIntent!.parameters['type'], 'MARKET');
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('signed-out read opens actual login without private reads or wallet creation', (
    tester,
  ) async {
    final identity = TestIdentityRepository(), repository = TestLiveOrderRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await read(tester);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.reads, 0);
    expect(repository.submits, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'review binds real wallet and exact amount; cancel preserves input; unknown is query-only',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await read(tester);
      await fill(tester);
      await visible(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      final dialog = find.byType(OrderConfirmationDialog);
      for (final text in ['BTCUSDT', '0.001 BTC', '80000 USDT']) {
        expect(
          find.descendant(of: dialog, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.submits, 0);
      // Loading directional capacity expands the form. Scroll again after the
      // cancelled dialog rather than tapping the old bottom-edge coordinates.
      await tester.ensureVisible(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      expect(repository.submits, 1);
      expect(
        tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
        '0.001',
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      repository.result = LiveOrderResult(
        orderId: '12345',
        status: 'NEW',
        executedQuantity: Decimal.zero,
      );
      await visible(tester, 'live-order-recheck');
      await tester.tap(find.byKey(const Key('live-order-recheck')));
      await tester.pumpAndSettle();
      expect(repository.checks, 1);
      expect(repository.submits, 1);
      expect(find.textContaining('Signed query: NEW'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  for (final locale in ['en', 'zh']) {
    testWidgets('narrow enlarged text and landscape order layout: $locale', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository();
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
      await read(tester);
      await fill(tester);
      await visible(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-review')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      expect(tester.takeException(), null);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(repository.submits, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}

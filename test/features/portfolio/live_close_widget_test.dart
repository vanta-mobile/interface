import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_card.dart';

import '../../support/order_confirmation_widget.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    if (key == 'live-order-read') {
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('live-order-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      170,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('live-order-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer container, {
    String side = 'BOTH',
  }) async {
    await launch(tester, container);
    openLiveClose(tester.element(find.byType(Navigator).first), 'BTCUSDT', side);
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('close fractions, slider, limit terms and cancel preserve inputs after refresh', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository()..context = liveCloseContext();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await visible(tester, 'live-close-fraction-50');
    expect(find.text('Close long · sell'), findsOneWidget);
    expect(find.byKey(const Key('live-order-price')), findsNothing);
    await tap(tester, 'live-close-fraction-50');
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
      '0.005',
    );
    final slider = tester.widget<Slider>(find.byKey(const Key('live-close-percentage')));
    expect(slider.value, 0.5);
    slider.onChanged!(0.75);
    slider.onChangeEnd!(0.75);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
      '0.007',
    );
    await tester.ensureVisible(find.text('Limit'));
    await tester.tap(find.text('Limit'));
    await tester.pumpAndSettle();
    await visible(tester, 'live-order-price');
    await tester.enterText(find.byKey(const Key('live-order-price')), '80000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tap(tester, 'live-order-review');
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.submits, 0);
    await tap(tester, 'live-order-read');
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
      '0.007',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
      '80000',
    );
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });

  testWidgets(
    'close unknown outcome is query-only and remaining position needs a fresh explicit read',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()
        ..context = liveCloseContext(short: true, hedge: true)
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      final risk = TestPositionRiskRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        positionRiskRepository: risk,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await open(tester, container, side: 'SHORT');
      await tap(tester, 'live-close-fraction-100');
      await tap(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      expect(repository.lastIntent!.side, 'BUY');
      expect(repository.lastIntent!.positionSide, 'SHORT');
      expect(repository.lastIntent!.parameters['reduceOnly'], null);
      expect(repository.submits, 1);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      repository.result = LiveOrderResult(
        orderId: '12345',
        status: 'FILLED',
        executedQuantity: Decimal.parse('0.01'),
        checkedAt: liveOrderClock,
      );
      await tap(tester, 'live-order-recheck');
      expect(repository.submits, 1);
      expect(repository.checks, 1);
      expect(risk.calls, 0);
      await tap(tester, 'live-close-read-remaining');
      expect(risk.calls, 1);
      // Old snapshot must never be presented as the remaining position after this close.
      expect(find.text('Remaining quantity at this read'), findsNothing);
      risk.result = mapPositionRisk(
        [
          positionRiskRow()
            ..['positionSide'] = 'SHORT'
            ..['positionAmt'] = '-0.004',
        ],
        address: accountAddress,
        receivedAt: liveOrderClock.add(const Duration(seconds: 1)),
        units: accountFixture().units,
      );
      await tap(tester, 'live-close-read-remaining');
      expect(find.text('0.004 BTC'), findsOneWidget);
      risk.failure = const AccountReadFailure('accountNetwork');
      await tap(tester, 'live-close-read-remaining');
      expect(find.text('0.004 BTC'), findsNothing);
      risk.failure = null;
      risk.result = PositionRiskSnapshot(
        address: accountAddress,
        receivedAt: liveOrderClock.add(const Duration(seconds: 1)),
        positions: [],
      );
      await tap(tester, 'live-close-read-remaining');
      expect(risk.calls, 4);
      expect(find.text('0 BTC'), findsOneWidget);
      container.read(positionRiskProvider.notifier).markStale();
      await tester.pumpAndSettle();
      expect(find.text('0 BTC'), findsNothing);
      expect(tester.takeException(), null);
      await dispose(tester, container);
    },
  );

  testWidgets(
    'position card opens close and TP/SL routes scoped to symbol and side without auto-signing',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository();
      final position = mapPositionRisk(
        [positionRiskRow()],
        address: accountAddress,
        receivedAt: liveOrderClock,
        units: accountFixture().units,
      ).positions.first;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
        language: const Locale('en'),
      );
      await launch(tester, container);
      Navigator.of(tester.element(find.byType(Navigator).first)).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SingleChildScrollView(child: PositionRiskCard(position: position)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final close = find.byKey(const Key('live-close-BTCUSDT-BOTH'));
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(tester.widget<LiveOrderScreen>(find.byType(LiveOrderScreen)).closingSide, 'BOTH');
      expect(repository.reads, 0);
      expect(repository.submits, 0);
      expect(identity.wallets, 0);
      Navigator.of(tester.element(find.byType(LiveOrderScreen))).pop();
      await tester.pumpAndSettle();
      final tpsl = find.byKey(const Key('live-tpsl-BTCUSDT-BOTH'));
      await tester.ensureVisible(tpsl);
      await tester.tap(tpsl);
      await tester.pumpAndSettle();
      final screen = tester.widget<LiveOrderScreen>(find.byType(LiveOrderScreen));
      expect(screen.closingSide, 'BOTH');
      expect(screen.initialConditional, true);
      expect(repository.reads, 0);
      expect(repository.submits, 0);
      await dispose(tester, container);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets('close confirmation and result fit 320 enlarged and landscape: $locale', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()..context = liveCloseContext();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(locale),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container);
      await tap(tester, 'live-close-fraction-25');
      await tap(tester, 'live-order-review');
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      expect(tester.takeException(), null);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      await visible(tester, 'live-close-read-remaining');
      expect(tester.takeException(), null);
      expect(repository.submits, 1);
      expect(identity.wallets, 0);
      await dispose(tester, container);
    });
  }
}

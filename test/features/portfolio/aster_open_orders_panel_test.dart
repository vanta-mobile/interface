import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';
import 'package:vanta/features/portfolio/presentation/trade_open_orders_section.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';
import '../../support/workspace_navigation.dart';

Future<void> _awaitAgent(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 50 && container.read(tradingAgentProvider).isLoading; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(container.read(tradingAgentProvider).value?.status, TradingAgentStatus.active);
}

Finder _inOrders(Finder finder) =>
    find.descendant(of: find.byType(TradeOpenOrdersSection), matching: finder);

void main() {
  testWidgets('without a trading grant nothing is read and no read button is offered', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, openOrdersRepository: orders);
    await launch(tester, container);
    await revealFuturesAccountTabs(tester);
    container.read(accountProvider.notifier).connect();
    await tester.pumpAndSettle();
    expect(find.byType(TradeOpenOrdersSection), findsOneWidget);
    expect(find.byKey(const Key('read-open-orders')), findsNothing);
    expect(_inOrders(find.text('10000.00')), findsNothing);
    expect(orders.calls, 0);
    expect(tester.takeException(), null);
  });

  testWidgets('active grant reads silently, filters current symbol and clears on logout', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()..gate = Completer<void>();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await _awaitAgent(tester, container);
    // The loaded grant completes onboarding; let the trading page mount.
    await tester.pumpAndSettle();
    await revealFuturesAccountTabs(tester);
    await tester.pump();
    await tester.pump();
    expect(orders.calls, 1);
    expect(find.byKey(const Key('read-open-orders')), findsNothing);
    expect(_inOrders(find.byKey(const Key('open-orders-skeleton'))), findsOneWidget);
    orders.gate!.complete();
    await tester.pumpAndSettle();
    expect(orders.calls, 1);
    expect(find.byType(AsterOpenOrderCard), findsNWidgets(2));
    expect(_inOrders(find.byKey(const Key('open-orders-skeleton'))), findsNothing);
    expect(find.byKey(const Key('open-order-BTCUSDT-1917641')), findsOneWidget);
    expect(find.textContaining('80,000.01'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    expect(find.byType(AsterOpenOrderCard), findsOneWidget);
    expect(find.byKey(const Key('open-order-ETHUSDT-1917642')), findsNothing);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-order-ETHUSDT-1917642')), findsOneWidget);
    expect(orders.calls, 1);

    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(openOrdersReadProvider).account, null);
    expect(find.byType(AsterOpenOrderCard), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('tapping a card opens its market at the top of the trade page', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await _awaitAgent(tester, container);
    await tester.pumpAndSettle();
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('futures-workspace')),
          matching: find.byType(Scrollable),
        )
        .first;
    final page = tester.state<ScrollableState>(scrollable);
    // At the top the account sections leave the sliver cache, so scroll back down.
    Future<void> tapCard(String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 300, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(page.position.pixels, greaterThan(0));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    expect(container.read(symbolProvider), 'BTCUSDT');
    await tapCard('open-order-ETHUSDT-1917642');
    expect(container.read(symbolProvider), 'ETHUSDT');
    expect(page.position.pixels, 0);
    expect(find.byKey(const Key('open-order-details')), findsNothing);

    await tapCard('open-order-ETHUSDT-1917642');
    expect(container.read(symbolProvider), 'ETHUSDT');
    expect(page.position.pixels, 0);
    expect(tester.takeException(), null);
    container.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed silent read stops automatic reads until Retry', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await _awaitAgent(tester, container);
    // The loaded grant completes onboarding; let the trading page mount.
    await tester.pumpAndSettle();
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    expect(orders.calls, 1);
    expect(_inOrders(find.textContaining('Aster error code: -2015')), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(orders.calls, 1);

    orders
      ..failure = null
      ..result = AsterOpenOrders(
        address: accountAddress,
        receivedAt: DateTime.utc(2026),
        orders: [],
      );
    await tester.ensureVisible(_inOrders(find.byKey(const Key('status-retry'))));
    await tester.pumpAndSettle();
    await tester.tap(_inOrders(find.byKey(const Key('status-retry'))));
    await tester.pumpAndSettle();
    expect(orders.calls, 2);
    expect(find.text('No open perpetual orders in this account.'), findsOneWidget);
    expect(tester.takeException(), null);
    container.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('app TP/SL orders show their exits read silently through the strategy service', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository()
      ..result = mapAsterOpenOrders(
        [
          {...openOrder(), 'clientOrderId': 'vanta-abc-def-1'},
          openOrder(symbol: 'ETHUSDT', id: 1917642),
        ],
        address: accountAddress,
        receivedAt: DateTime.utc(2026),
      );
    final strategies = TestOpenOrderStrategyRepository()
      ..result = OpenOrderStrategy(
        strategyId: '77',
        type: 'OTOCO',
        sequence: 1,
        takeProfit: Decimal.parse('90000'),
        stopLoss: Decimal.parse('70000'),
      );
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      openOrderStrategyRepository: strategies,
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await _awaitAgent(tester, container);
    // The loaded grant completes onboarding; let the trading page mount.
    await tester.pumpAndSettle();
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    expect(strategies.queries.single.parameters, {'clientStrategyId': 'vanta-abc-def'});
    await tester.ensureVisible(find.byKey(const Key('open-order-tpsl')));
    await tester.pumpAndSettle();
    expect(find.text('90,000 / 70,000', findRichText: true), findsOneWidget);
    expect(find.byKey(const Key('open-order-tpsl')), findsOneWidget);
    expect(tester.takeException(), null);
    container.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  for (final spec in [
    (360.0, 844.0, 1.5, 'zh'),
    (390.0, 844.0, 2.0, 'en'),
    (844.0, 390.0, 1.5, 'en'),
  ]) {
    testWidgets('open orders fit narrow and landscape layouts $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final orders = TestOpenOrdersRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        openOrdersRepository: orders,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      await revealFuturesAccountTabs(tester);
      await container.read(openOrdersReadProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-order-BTCUSDT-1917641')));
      await tester.pumpAndSettle();
      expect(find.byType(AsterOpenOrderCard), findsNWidgets(2));
      expect(tester.takeException(), null);
      container.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
}

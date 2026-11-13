import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/trade_position_card.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/navigation_fixture.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';
import '../../support/workspace_navigation.dart';

Future<({ProviderContainer container, NavigationIdentity identity})> mount(
  WidgetTester t, {
  required TestPositionRiskRepository positions,
  required TestOpenOrdersRepository orders,
  bool authorized = true,
}) async {
  final identity = NavigationIdentity()..restored = signingIdentity;
  addTearDown(identity.dispose);
  final store = await t.runAsync(() async {
    final store = MemoryTradingAgentStorage().store(DateTime.now);
    if (authorized) {
      final agent = await store.prepare(
        signingIdentity.id,
        accountAddress,
        DateTime.now().add(const Duration(days: 30)),
      );
      await store.setStatus(agent, TradingAgentStatus.unknown);
      await store.setStatus(agent, TradingAgentStatus.active);
    }
    return store;
  });
  final c = setup(
    t,
    identityRepository: identity,
    positionRiskRepository: positions,
    openOrdersRepository: orders,
    tradingAgentStore: store!,
    language: const Locale('en'),
  );
  await launch(t, c);
  for (var i = 0; i < 50 && c.read(tradingAgentProvider).isLoading; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump();
  }
  await t.pumpAndSettle();
  return (container: c, identity: identity);
}

void main() {
  testWidgets('an outside request opens its account tab and scrolls it into view once', (t) async {
    final f = await mount(
      t,
      positions: TestPositionRiskRepository(),
      orders: TestOpenOrdersRepository(),
    );
    final tab = find.byKey(const Key('futures-account-tab-1'));
    final view = t.getRect(find.byKey(const Key('futures-workspace')));
    expect(view.contains(t.getCenter(tab)), isFalse, reason: 'tabs start below the form');
    f.container.read(futuresAccountRequestProvider.notifier).show(FuturesAccountTab.positions);
    await t.pumpAndSettle();
    expect(find.byType(TradePositionCard), findsOneWidget);
    expect(view.contains(t.getCenter(tab)), isTrue);
    expect(f.container.read(futuresAccountRequestProvider), isNull, reason: 'consumed');
    await t.tap(find.byKey(const Key('futures-account-tab-0')));
    await t.pumpAndSettle();
    expect(find.byType(TradePositionCard), findsNothing, reason: 'user choice still wins');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    f.container.dispose();
    await t.pump();
  });

  testWidgets('entry reads tab counts before selecting Positions without building its cards', (
    t,
  ) async {
    final positions = TestPositionRiskRepository();
    final orders = TestOpenOrdersRepository();
    final f = await mount(t, positions: positions, orders: orders);
    expect(positions.calls, 1);
    expect(orders.calls, 1);
    expect(find.byType(TradePositionCard), findsNothing);
    await revealFuturesAccountTabs(t);
    expect(find.text('Positions (1)'), findsOneWidget);
    expect(find.text('Open (${orders.result.orders.length})'), findsOneWidget);
    await t.tap(find.byKey(const Key('futures-account-tab-1')));
    await t.pumpAndSettle();
    expect(find.byType(TradePositionCard), findsOneWidget);
    expect(positions.calls, 1);
    expect(orders.calls, 1);
    expect(f.identity.signatures, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    f.container.dispose();
    await t.pump();
  });

  testWidgets('pending and failed initial reads never display a fabricated zero or loop retries', (
    t,
  ) async {
    final positions = TestPositionRiskRepository()..gate = Completer<void>();
    final orders = TestOpenOrdersRepository();
    final f = await mount(t, positions: positions, orders: orders);
    expect(positions.calls, 1);
    await revealFuturesAccountTabs(t);
    expect(find.text('Positions'), findsOneWidget);
    expect(find.text('Positions (0)'), findsNothing);
    positions.failure = const AccountReadFailure('accountReadFailed');
    positions.gate!.complete();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('futures-account-tab-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('futures-account-tab-0')));
    await t.pumpAndSettle();
    expect(positions.calls, 1);
    expect(find.text('Positions'), findsOneWidget);
    expect(find.text('Positions (0)'), findsNothing);
    expect(f.identity.signatures, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    f.container.dispose();
    await t.pump();
  });

  testWidgets('entry without a device grant never starts private count reads or wallet prompts', (
    t,
  ) async {
    final positions = TestPositionRiskRepository();
    final orders = TestOpenOrdersRepository();
    final f = await mount(t, positions: positions, orders: orders, authorized: false);
    await revealFuturesAccountTabs(t);
    expect(positions.calls, 0);
    expect(orders.calls, 0);
    expect(f.identity.signatures, 0);
    expect(find.text('Positions'), findsOneWidget);
    expect(find.text('Positions (0)'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    f.container.dispose();
    await t.pump();
  });
}

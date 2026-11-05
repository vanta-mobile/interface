import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_orders_panel.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('signed-out read prompts login; demo funds never appear in real orders', (
    tester,
  ) async {
    final identity = TestIdentityRepository();
    final orders = TestOpenOrdersRepository();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, openOrdersRepository: orders);
    await launch(tester, container);
    container.read(accountProvider.notifier).connect();
    expect(find.byType(AsterOpenOrdersPanel), findsOneWidget);
    expect(find.byKey(const Key('open-orders-count')), findsNothing);
    expect(
      find.descendant(of: find.byType(AsterOpenOrdersPanel), matching: find.text('10000.00')),
      findsNothing,
    );
    expect(orders.calls, 0);
    await tester.ensureVisible(find.byKey(const Key('read-open-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-open-orders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(orders.calls, 0);
    expect(tester.takeException(), null);
  });

  testWidgets('manual read filters current symbol, retains failed snapshot and clears on logout', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
    );
    await launch(tester, container);
    expect(orders.calls, 0);
    orders.gate = Completer<void>();
    await tester.ensureVisible(find.byKey(const Key('read-open-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-open-orders')));
    await tester.pump();
    expect(orders.calls, 1);
    expect(find.text('Confirm the account read signature in your wallet.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('read-open-orders'))).onPressed, null);
    orders.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open orders (2)'), findsOneWidget);
    expect(find.byType(AsterOpenOrderCard), findsNWidgets(2));
    expect(find.text('Partially filled'), findsOneWidget);
    expect(find.byKey(const Key('open-order-BTCUSDT-1917641')), findsOneWidget);
    expect(find.textContaining('32,000.004'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    expect(find.text('Open orders (1)'), findsOneWidget);
    expect(find.byKey(const Key('open-order-BTCUSDT-1917641')), findsOneWidget);
    expect(find.byKey(const Key('open-order-ETHUSDT-1917642')), findsNothing);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    await tester.pumpAndSettle();
    expect(find.text('Open orders (1)'), findsOneWidget);
    expect(find.byKey(const Key('open-order-ETHUSDT-1917642')), findsOneWidget);
    expect(orders.calls, 1);

    orders.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    await tester.ensureVisible(find.byKey(const Key('read-open-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-open-orders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-orders-snapshot-stale')), findsOneWidget);
    expect(find.textContaining('Aster error code: -2015'), findsOneWidget);
    expect(find.text('Open orders (1)'), findsOneWidget);
    container.read(localeProvider.notifier).select('zh');
    await tester.pumpAndSettle();
    expect(find.text('Aster 合约挂单'), findsOneWidget);
    expect(find.text('挂单（1）'), findsOneWidget);
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(container.read(openOrdersReadProvider).account, null);
    expect(find.byKey(const Key('open-orders-count')), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('successful empty orders differ from failed read and current-symbol empty state', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      language: const Locale('en'),
    );
    await launch(tester, container);
    orders.failure = const AccountReadFailure('accountNetwork');
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-orders-empty')), findsNothing);
    orders.failure = null;
    orders.result = AsterOpenOrders(
      address: accountAddress,
      receivedAt: DateTime.utc(2026),
      orders: [],
    );
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('No open perpetual orders in this account.'), findsOneWidget);
    orders.result = openOrdersFixture();
    await container.read(openOrdersReadProvider.notifier).refresh();
    container.read(symbolProvider.notifier).select('SOLUSDT');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    expect(find.text('No open orders for the current symbol.'), findsOneWidget);
    container.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  for (final spec in [
    (360.0, 844.0, 1.5, 'zh'),
    (390.0, 844.0, 2.0, 'en'),
    (844.0, 390.0, 1.5, 'en'),
  ]) {
    testWidgets('open orders fit narrow and landscape layouts', (tester) async {
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

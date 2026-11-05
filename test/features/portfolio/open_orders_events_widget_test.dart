import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_orders_panel.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';

import '../../support/account_changes.dart';
import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/open_order_updates.dart';
import '../../support/order_cancellation.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: SafeArea(child: SingleChildScrollView(child: AsterOpenOrdersPanel())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'authenticated events change filtered count, fills and final removal while keeping REST scope historical',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final changes = TestAccountChangeRepository();
      final orders = TestOpenOrdersRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        identityRepository: identity,
        asterAccountRepository: TestAsterAccountRepository(),
        openOrdersRepository: orders,
        accountChangeRepository: changes,
        monitorClock: () => changes.now,
      );
      addTearDown(identity.dispose);
      await open(tester, container);
      await container.read(openOrdersReadProvider.notifier).refresh();
      await container.read(accountChangeProvider.notifier).authorize();
      changes.channels.last.add(const AccountChangeEvent.connected());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
      await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
      await tester.pumpAndSettle();
      expect(find.text('Open orders (1)'), findsOneWidget);
      final partial = orderUpdate();
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, partial.eventTime, order: partial),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(openOrdersReadProvider).account!.orders.last.executedQty.toString(),
        '0.1',
      );
      expect(find.text('0.10 BTC / 0.40 BTC'), findsOneWidget);
      expect(find.text('0.30 BTC'), findsOneWidget);
      expect(find.byKey(const Key('open-orders-event-time')), findsOneWidget);
      expect(find.byKey(const Key('open-orders-snapshot-stale')), findsOneWidget);
      final newOrder = orderUpdate(
        id: '555',
        status: 'NEW',
        filled: '0',
        eventTime: orderEventClock + 1,
      );
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, newOrder.eventTime, order: newOrder),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open orders (2)'), findsOneWidget);
      expect(find.text('Unknown · read orders to verify'), findsOneWidget);
      final terminal = orderUpdate(status: 'FILLED', filled: '0.4', eventTime: orderEventClock + 2);
      changes.channels.last.add(
        AccountChangeEvent.changed(AccountChangeKind.order, terminal.eventTime, order: terminal),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open orders (1)'), findsOneWidget);
      expect(find.byKey(const Key('open-order-BTCUSDT-1917641')), findsNothing);
      expect(orders.calls, 1);
      expect(changes.authorizations, 1);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await changes.dispose();
    },
  );
  testWidgets(
    'order-list monitor entry opens same monitor scope and sign-in without creating wallets',
    (tester) async {
      final identity = TestIdentityRepository();
      final changes = TestAccountChangeRepository();
      final container = setup(
        tester,
        language: const Locale('zh'),
        identityRepository: identity,
        accountChangeRepository: changes,
        monitorClock: () => changes.now,
      );
      addTearDown(identity.dispose);
      await open(tester, container);
      await tester.tap(find.byKey(const Key('open-order-monitor')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('authorize-account-changes')));
      await tester.tap(find.byKey(const Key('authorize-account-changes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(changes.authorizations, 0);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await changes.dispose();
    },
  );
  testWidgets('cancel report warns when a private order event overtakes its status query', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final orders = TestOpenOrdersRepository();
    final cancellation = TestOrderCancellationRepository()..gate = Completer<void>();
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      openOrdersRepository: orders,
      orderCancellationRepository: cancellation,
    );
    addTearDown(identity.dispose);
    await open(tester, container);
    await container.read(openOrdersReadProvider.notifier).refresh();
    final order = container.read(openOrdersReadProvider).account!.orders.last;
    cancellation.result = OrderCancellationResult(
      resolution: OrderResolution(
        symbol: order.symbol,
        orderId: order.orderId,
        status: 'NEW',
        openOrder: order,
      ),
    );
    final controller = container.read(orderCancellationProvider.notifier);
    final pending = controller.cancel(controller.prepare(order)!);
    container
        .read(openOrdersReadProvider.notifier)
        .applyEvent(orderUpdate(status: 'FILLED', filled: '0.40'));
    cancellation.gate!.complete();
    await pending;
    await tester.pumpAndSettle();
    expect(find.textContaining('Order events arrived during verification.'), findsOneWidget);
    expect(find.textContaining('Aster reports this order is still open.'), findsNothing);
    expect(cancellation.cancels, 1);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('new-event unknown creation and precise amounts fit $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      addTearDown(identity.dispose);
      await launch(tester, container);
      final order = orderUpdate().toOrder();
      final context = tester.element(find.byType(Navigator).first);
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(child: AsterOpenOrderCard(order: order)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = find.text(spec.$4 == 'en' ? 'Unknown · read orders to verify' : '未知 · 请读取订单核对');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      expect(label, findsOneWidget);
      expect(find.textContaining('80,000.01'), findsWidgets);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/domain/order_modification.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';
import '../../support/workspace_navigation.dart';

class _ModificationRepository implements OrderModificationRepository {
  final requests = <OrderModification>[];
  Completer<void>? gate;
  OrderModificationResult Function(OrderModification request) respond = (request) =>
      OrderModificationResult(
        OrderModifyOutcome.modified,
        order: AsterOpenOrder(
          symbol: request.order.symbol,
          orderId: request.order.orderId,
          side: request.order.side,
          positionSide: request.order.positionSide,
          type: request.order.type,
          status: request.order.status,
          time: request.order.time,
          origQty: request.quantity,
          executedQty: request.order.executedQty,
          price: request.price,
          units: request.order.units,
        ),
      );

  @override
  Future<OrderModificationResult> modify({
    required String address,
    required OrderModification request,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) async {
    requests.add(request);
    onStep(OrderCancelStep.submitting);
    await gate?.future;
    return respond(request);
  }
}

const _btc = 'edit-order-BTCUSDT-1917641';

void main() {
  late _ModificationRepository modifications;
  late TestOpenOrdersRepository orders;

  Future<ProviderContainer> open(WidgetTester tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    modifications = _ModificationRepository();
    orders = TestOpenOrdersRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: orders,
      orderModificationRepository: modifications,
      tradingAgentStore: await tester.runAsync(activeAgentStore),
      verifiedApiSession: true,
      language: const Locale('en'),
    );
    await launch(tester, container);
    for (var i = 0; i < 50 && container.read(tradingAgentProvider).isLoading; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(container.read(tradingAgentProvider).value?.status, TradingAgentStatus.active);
    await tester.pumpAndSettle();
    await revealFuturesAccountTabs(tester);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    // Let the result toast expire before tearing down.
    await tester.pump(const Duration(seconds: 5));
    container.dispose();
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> tapEdit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key(_btc)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key(_btc)));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String price, String amount) async {
    await tester.enterText(find.byKey(const Key('open-order-edit-price')), price);
    await tester.enterText(find.byKey(const Key('open-order-edit-amount')), amount);
    await tester.tap(find.byKey(const Key('open-order-edit-confirm')));
    await tester.pump();
  }

  testWidgets('only LIMIT orders without TP/SL offer Edit; a change is submitted once', (
    tester,
  ) async {
    final container = await open(tester);
    expect(find.byKey(const Key(_btc)), findsOneWidget);
    // The ETH row is a STOP_MARKET order, which Aster cannot modify.
    expect(find.byKey(const Key('edit-order-ETHUSDT-1917642')), findsNothing);

    await tapEdit(tester);
    expect(find.text('Edit Price/Amount'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('open-order-edit-price'))).controller!.text,
      '80000.01',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('open-order-edit-amount'))).controller!.text,
      '0.40',
    );
    expect(find.textContaining('time priority is reset'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-order-edit-confirm')));
    await tester.pump();
    expect(find.text('Change the price or amount before confirming.'), findsOneWidget);
    await enter(tester, '0', '0.4');
    expect(find.text('Enter a price greater than 0.'), findsOneWidget);
    expect(modifications.requests, isEmpty);

    modifications.gate = Completer<void>();
    await enter(tester, '79000.5', '0.5');
    expect(find.byKey(const Key('position-action-loading')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-order-edit-confirm')));
    await tester.pump();
    expect(modifications.requests, hasLength(1));
    expect(modifications.requests.single.price, Decimal.parse('79000.5'));
    expect(modifications.requests.single.quantity, Decimal.parse('0.5'));

    modifications.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Order modified.'), findsOneWidget);
    expect(find.byKey(const Key('open-order-edit-sheet')), findsNothing);
    final updated = container
        .read(openOrdersReadProvider)
        .account!
        .orders
        .firstWhere((o) => o.symbol == 'BTCUSDT');
    expect(updated.price, Decimal.parse('79000.5'));
    expect(updated.origQty, Decimal.parse('0.5'));
    await close(tester, container);
  });

  testWidgets('a rejection keeps the sheet and input; an unknown result closes it', (tester) async {
    final container = await open(tester);
    modifications.respond = (request) => OrderModificationResult(
      OrderModifyOutcome.rejected,
      order: request.order,
      failure: const AccountReadFailure('accountReadFailed', code: -4014),
    );
    await tapEdit(tester);
    await enter(tester, '79000.5', '0.5');
    await tester.pumpAndSettle();
    expect(find.textContaining('Order not modified'), findsOneWidget);
    expect(find.byKey(const Key('open-order-edit-sheet')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('open-order-edit-price'))).controller!.text,
      '79000.5',
    );
    await tester.pump(const Duration(seconds: 5));

    modifications.respond = (_) => const OrderModificationResult(OrderModifyOutcome.unknown);
    await tester.tap(find.byKey(const Key('open-order-edit-confirm')));
    await tester.pumpAndSettle();
    expect(modifications.requests, hasLength(2));
    expect(find.textContaining('modification result is unconfirmed'), findsOneWidget);
    expect(find.byKey(const Key('open-order-edit-sheet')), findsNothing);
    // The auto reader re-reads the stale snapshot silently once its 5 s spacing allows.
    expect(container.read(openOrdersReadProvider).stale, true);
    await close(tester, container);
  });
}

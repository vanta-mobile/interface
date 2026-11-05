import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/strategy_execution.dart';

import 'attached_order.dart';
import 'live_order.dart';

class StrategyExecutionFixture {
  StrategyExecutionFixture({LiveOrderIntent? intent}) : intent = intent ?? attachedIntent();
  final LiveOrderIntent intent;
  late final query = StrategyExecutionQuery(order: OrderQuery.capture(intent), strategyId: '9876');
  Map<String, dynamic> strategy({bool allIds = true}) {
    final payload = attachedQuery(intent);
    if (allIds) {
      final legs = payload['subOrders'] as List;
      for (var i = 0; i < legs.length; i++) {
        (legs[i] as Map)['orderId'] = 100 + i;
      }
    }
    return payload;
  }

  Map<String, dynamic> order(int sequence) {
    final leg = (strategy()['subOrders'] as List)[sequence - 1] as Map;
    return {
      'orderId': 99 + sequence,
      'clientOrderId': leg['clientOrderId'],
      'symbol': 'BTCUSDT',
      'side': leg['side'],
      'positionSide': leg['positionSide'],
      'reduceOnly': leg['reduceOnly'],
      'closePosition': false,
      'origType': leg['type'],
      'type': leg['type'],
      'timeInForce': leg['timeInForce'],
      'origQty': leg['quantity'],
      'executedQty': sequence == 1 ? '0.0004' : '0',
      'cumQuote': sequence == 1 ? '32.000000000000000001' : '0',
      'avgPrice': sequence == 1 ? '80000' : '0',
      'price': sequence == 1 && intent.draft.pegged ? '80000' : leg['price'],
      'stopPrice': leg['stopPrice'],
      'workingType': leg['workingType'],
      'priceProtect': leg['priceProtect'],
      'status': sequence == 1 ? 'CANCELED' : 'NEW',
      'time': liveOrderClock.millisecondsSinceEpoch - 1000,
      'updateTime': liveOrderClock.millisecondsSinceEpoch,
    };
  }

  StrategyExecutionSnapshot snapshot({StrategyExecutionQuery? request}) =>
      StrategyExecutionSnapshot(
        query: request ?? query,
        strategy: AttachedOrderSnapshot(
          strategyId: '9876',
          status: 'WORKING',
          legs: const [
            AttachedOrderLeg(sequence: 1, status: 'PARTIALLY_FILLED', orderId: '100'),
            AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW', orderId: '101'),
            AttachedOrderLeg(sequence: 3, status: 'PENDING_NEW'),
          ],
        ),
        strategyCheckedAt: liveOrderClock,
        receivedAt: liveOrderClock,
        units: const AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'),
        legs: [
          StrategyExecutionLeg(
            strategyLeg: const AttachedOrderLeg(
              sequence: 1,
              status: 'PARTIALLY_FILLED',
              orderId: '100',
            ),
            execution: StrategyLegExecution(
              orderId: '100',
              status: 'CANCELED',
              type: 'LIMIT',
              originalType: 'LIMIT',
              quantity: Decimal.parse('0.001'),
              executed: Decimal.parse('0.0004'),
              price: Decimal.parse('80000'),
              quoteAmount: Decimal.parse('32.000000000000000001'),
              averagePrice: Decimal.parse('80000'),
              createdAt: liveOrderClock,
              updatedAt: liveOrderClock,
              checkedAt: liveOrderClock,
              termsChanged: false,
            ),
          ),
          StrategyExecutionLeg(
            strategyLeg: const AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW', orderId: '101'),
            execution: StrategyLegExecution(
              orderId: '101',
              status: 'NEW',
              type: 'LIMIT',
              originalType: 'TAKE_PROFIT',
              quantity: Decimal.parse('0.0004'),
              executed: Decimal.zero,
              price: Decimal.parse('81000'),
              quoteAmount: Decimal.zero,
              averagePrice: Decimal.zero,
              createdAt: liveOrderClock,
              updatedAt: liveOrderClock,
              checkedAt: liveOrderClock,
              termsChanged: true,
            ),
          ),
          const StrategyExecutionLeg(
            strategyLeg: AttachedOrderLeg(sequence: 3, status: 'PENDING_NEW'),
          ),
        ],
      );
}

class TestStrategyExecutionRepository implements StrategyExecutionRepository {
  TestStrategyExecutionRepository(this.fixture);
  final StrategyExecutionFixture fixture;
  int calls = 0;
  AccountReadFailure? failure;
  Completer<void>? gate;
  bool Function()? current;
  bool wrongQuery = false;
  StrategyExecutionSnapshot Function(StrategyExecutionQuery)? result;
  @override
  Future<StrategyExecutionSnapshot> read(
    StrategyExecutionQuery query, {
    required bool Function() isCurrent,
    required void Function(AccountReadStep step, int? sequence) onStep,
  }) async {
    calls++;
    current = isCurrent;
    onStep(AccountReadStep.signing, null);
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (failure != null) throw failure!;
    onStep(AccountReadStep.loading, 1);
    return result?.call(query) ??
        fixture.snapshot(request: wrongQuery ? StrategyExecutionFixture().query : query);
  }
}

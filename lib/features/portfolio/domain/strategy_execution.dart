import 'package:decimal/decimal.dart';

import 'aster_account.dart';
import 'live_order_attachment.dart';
import 'order_query.dart';

class StrategyExecutionQuery {
  const StrategyExecutionQuery({required this.order, required this.strategyId});
  final OrderQuery order;
  final String strategyId;
}

/// Read-time ordinary-order evidence, kept separate from the strategy snapshot.
/// Quantity differences are reported; they are never treated as replenishment.
class StrategyLegExecution {
  const StrategyLegExecution({
    required this.orderId,
    required this.status,
    required this.type,
    required this.originalType,
    required this.quantity,
    required this.executed,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    required this.checkedAt,
    required this.termsChanged,
    this.quoteAmount,
    this.averagePrice,
  });
  final String orderId, status, type, originalType;
  final Decimal quantity, executed, price;
  final Decimal? quoteAmount, averagePrice;
  final DateTime createdAt, updatedAt, checkedAt;
  final bool termsChanged;
  bool get triggered =>
      (originalType != type || executed > Decimal.zero) &&
      const {'STOP', 'STOP_MARKET', 'TAKE_PROFIT', 'TAKE_PROFIT_MARKET'}.contains(originalType);
}

class StrategyExecutionLeg {
  const StrategyExecutionLeg({required this.strategyLeg, this.execution, this.failure});
  final AttachedOrderLeg strategyLeg;
  final StrategyLegExecution? execution;
  final AccountReadFailure? failure;
}

class StrategyExecutionSnapshot {
  StrategyExecutionSnapshot({
    required this.query,
    required this.strategy,
    required this.strategyCheckedAt,
    required this.receivedAt,
    required Iterable<StrategyExecutionLeg> legs,
    this.units,
  }) : legs = List.unmodifiable(legs);
  final StrategyExecutionQuery query;
  final AttachedOrderSnapshot strategy;
  final DateTime strategyCheckedAt, receivedAt;
  final AsterContractUnits? units;
  final List<StrategyExecutionLeg> legs;
}

class StrategyExecutionState {
  const StrategyExecutionState({
    this.snapshot,
    this.failure,
    this.step = AccountReadStep.idle,
    this.stale = false,
    this.sequence,
  });
  final StrategyExecutionSnapshot? snapshot;
  final AccountReadFailure? failure;
  final AccountReadStep step;
  final bool stale;
  final int? sequence;
  bool get busy => step != AccountReadStep.idle;
}

abstract interface class StrategyExecutionRepository {
  Future<StrategyExecutionSnapshot> read(
    StrategyExecutionQuery query, {
    required bool Function() isCurrent,
    required void Function(AccountReadStep step, int? sequence) onStep,
  });
}

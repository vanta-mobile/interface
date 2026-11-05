import 'live_order_trigger.dart';
import 'attached_entry_peg.dart';

enum AttachedExitExecution { market, manualLimit, automaticLimit }

enum AttachedOrderDrivenOn {
  partialOrFilled('PARTIALLY_FILLED_OR_FILLED'),
  filled('FILLED');

  const AttachedOrderDrivenOn(this.wire);
  final String wire;
}

class AttachedExit extends LiveOrderTrigger {
  const AttachedExit({
    required super.kind,
    required super.price,
    super.basis = LiveOrderTriggerBasis.mark,
    super.protect,
    this.execution = AttachedExitExecution.market,
    this.limitPrice,
  });
  final AttachedExitExecution execution;
  final String? limitPrice;
  bool get market => execution == AttachedExitExecution.market;
  String? get executionPrice => switch (execution) {
    AttachedExitExecution.market => null,
    AttachedExitExecution.manualLimit => limitPrice,
    AttachedExitExecution.automaticLimit => price,
  };
  bool get validExecutionShape =>
      execution == AttachedExitExecution.manualLimit || limitPrice == null;
}

/// New strategies protect the full main-order quantity. Persisted queries keep
/// their original quantity and driving event, including legacy FILLED records.
class LiveOrderAttachment {
  const LiveOrderAttachment({
    this.takeProfit,
    this.stopLoss,
    this.entryPeg,
    this.drivenOn = AttachedOrderDrivenOn.partialOrFilled,
  });
  final AttachedEntryPeg? entryPeg;
  final AttachedExit? takeProfit, stopLoss;
  final AttachedOrderDrivenOn drivenOn;
  List<AttachedExit> get exits => [?takeProfit, ?stopLoss];
  String get strategyType => exits.length == 2 ? 'OTOCO' : 'OTO';
}

class AttachedOrderLeg {
  const AttachedOrderLeg({required this.sequence, required this.status, this.orderId});
  final int sequence;
  final String status;
  final String? orderId;
}

/// The strategy query does not document executed quantities. Do not derive
/// fills, balances, or remaining positions from these statuses.
class AttachedOrderSnapshot {
  AttachedOrderSnapshot({
    required this.strategyId,
    required this.status,
    required Iterable<AttachedOrderLeg> legs,
  }) : legs = List.unmodifiable(legs);
  final String strategyId, status;
  final List<AttachedOrderLeg> legs;
}

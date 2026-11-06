import 'account_snapshot.dart';
import 'live_order.dart';
import 'live_order_attachment.dart';
import 'live_order_capacity.dart';
import 'main_order_capacity.dart';
import 'main_order_capacity_preview.dart';
import 'main_order_revaluation.dart';

class MainOrderCapacityExceeded extends AccountReadFailure {
  const MainOrderCapacityExceeded({required this.capacity, required this.context})
    : super('liveCapacityAboveMaximum');
  final LiveOrderSideCapacity capacity;
  final LiveOrderContext context;
}

class MainOrderAllocationReview {
  const MainOrderAllocationReview({
    required this.intent,
    required this.capacity,
    required this.side,
    required this.revision,
    this.valuation,
  });
  final LiveOrderIntent intent;
  final MainOrderCapacitySnapshot capacity;
  final MainOrderSidePreview side;
  final MainOrderRevaluation? valuation;
  final int revision;
}

class MainOrderAllocationState {
  const MainOrderAllocationState({
    this.percent = 0,
    this.preparing = false,
    this.review,
    this.failure,
  });

  /// Null means independent manual input. Zero is the blank initial ratio.
  final int? percent;
  final bool preparing;
  final MainOrderAllocationReview? review;
  final AccountReadFailure? failure;
}

/// Structural, exact draft equality for a frozen review. No hash or rounding.
Object liveOrderDraftKey(LiveOrderDraft d) {
  Object? exitKey(AttachedExit? exit) => exit == null
      ? null
      : (exit.kind, exit.price, exit.basis, exit.protect, exit.execution, exit.limitPrice);
  final trigger = d.trigger, trailing = d.trailing, attachment = d.attachment;
  return (
    d.buy,
    d.market,
    d.quantity,
    d.price,
    d.reduceOnly,
    d.closingSide,
    d.timeInForce,
    d.entireClose,
    d.quickEntry,
    d.peg,
    trigger == null ? null : (trigger.kind, trigger.price, trigger.basis, trigger.protect),
    trailing == null ? null : (trailing.callbackRate, trailing.activationPrice, trailing.basis),
    attachment == null
        ? null
        : (
            exitKey(attachment.takeProfit),
            exitKey(attachment.stopLoss),
            attachment.entryPeg,
            attachment.drivenOn,
          ),
  );
}

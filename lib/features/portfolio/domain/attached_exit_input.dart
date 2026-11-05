import 'package:decimal/decimal.dart';

import 'attached_order.dart';
import 'futures_position_mode.dart';
import 'live_order.dart';
import 'live_order_attachment.dart';
import 'live_order_trigger.dart';

enum AttachedExitInputMode { pnl, price, roi }

/// Unsigned form intent. Derived prices are recomputed whenever the entry,
/// quantity, leverage or read-time context changes, before capturing an order.
class AttachedExitInput {
  const AttachedExitInput({
    required this.kind,
    this.mode = AttachedExitInputMode.pnl,
    this.value = '',
    this.basis = LiveOrderTriggerBasis.mark,
    this.execution = AttachedExitExecution.market,
    this.limitPrice = '',
    this.protect = false,
  });
  final LiveOrderTriggerKind kind;
  final AttachedExitInputMode mode;
  final String value, limitPrice;
  final LiveOrderTriggerBasis basis;
  final AttachedExitExecution execution;
  final bool protect;

  AttachedExitInput withExecution(AttachedExitExecution value) => AttachedExitInput(
    kind: kind,
    mode: mode,
    value: this.value,
    basis: basis,
    execution: value,
    limitPrice: limitPrice,
    protect: protect,
  );

  AttachedExitResolution resolve(LiveOrderContext data, LiveOrderDraft entry) {
    final quantity = parseOrderDecimal(entry.quantity);
    final reference = attachedEntryReference(data, entry);
    Decimal? trigger;
    String? failure;
    if (mode == AttachedExitInputMode.price) {
      trigger = parseOrderDecimal(value);
      if (trigger == null || trigger <= Decimal.zero) failure = 'liveOrderInvalidTrigger';
    } else {
      final target = _signedTarget(value);
      if (target == null ||
          target == Decimal.zero ||
          (kind == LiveOrderTriggerKind.takeProfit
              ? target < Decimal.zero
              : target > Decimal.zero)) {
        failure = 'attachedOrderTargetSign';
      } else if (reference == null ||
          reference <= Decimal.zero ||
          quantity == null ||
          quantity <= Decimal.zero ||
          data.leverage <= 0) {
        failure = 'attachedOrderPreviewUnavailable';
      } else {
        final delta = mode == AttachedExitInputMode.pnl
            ? target / quantity
            : (reference * target) / Decimal.fromInt(100 * data.leverage);
        final raw =
            reference.toRational() + delta * Decimal.fromInt(entry.buy ? 1 : -1).toRational();
        final tick = data.rules.priceTick;
        if (tick <= Decimal.zero) {
          failure = 'attachedOrderPreviewUnavailable';
        } else {
          // Keep division rational through alignment, including repeating ratios.
          final steps = ((raw - data.rules.priceMinimum.toRational()) / tick.toRational()).round();
          trigger = data.rules.priceMinimum + Decimal.fromBigInt(steps) * tick;
          if (trigger <= Decimal.zero) failure = 'liveOrderInvalidTrigger';
        }
      }
    }
    final exit = AttachedExit(
      kind: kind,
      price: trigger?.toString() ?? '',
      basis: basis,
      protect: protect,
      execution: execution,
      limitPrice: execution == AttachedExitExecution.manualLimit ? limitPrice : null,
    );
    if (failure == null && execution == AttachedExitExecution.manualLimit) {
      final limit = parseOrderDecimal(limitPrice);
      if (limit == null || limit <= Decimal.zero) failure = 'attachedOrderLimitRequired';
    }
    failure ??= data.rules.validate(
      LiveOrderDraft(
        buy: !entry.buy,
        market: exit.market,
        quantity: entry.quantity,
        price: exit.executionPrice ?? '',
        trigger: exit,
      ),
      data.markPrice,
      exemptNotional: data.mode == FuturesPositionMode.oneWay,
    );
    if (failure == null && entry.attachment?.entryPeg == null) {
      if (reference == null || reference <= Decimal.zero) {
        failure = 'attachedOrderPreviewUnavailable';
      } else if (exit.rises(!entry.buy) ? trigger! <= reference : trigger! >= reference) {
        failure = 'attachedOrderPriceDirection';
      }
    }
    final executionPrice = exit.market ? trigger : parseOrderDecimal(exit.executionPrice ?? '');
    final pnl = reference == null || executionPrice == null || quantity == null
        ? null
        : (executionPrice - reference) * quantity * Decimal.fromInt(entry.buy ? 1 : -1);
    final roi =
        pnl == null ||
            reference == null ||
            reference <= Decimal.zero ||
            quantity == null ||
            quantity <= Decimal.zero ||
            data.leverage <= 0
        ? null
        : ((pnl * Decimal.fromInt(100 * data.leverage)) / (reference * quantity)).toDecimal(
            scaleOnInfinitePrecision: 8,
            toBigInt: (value) => value.round(),
          );
    return AttachedExitResolution(exit: exit, failure: failure, pnl: pnl, roi: roi);
  }
}

Decimal? _signedTarget(String text) {
  if (text.length > 80 || !RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(text)) return null;
  return Decimal.tryParse(text.startsWith('+') ? text.substring(1) : text);
}

class AttachedExitResolution {
  const AttachedExitResolution({required this.exit, this.failure, this.pnl, this.roi});
  final AttachedExit exit;
  final String? failure;
  final Decimal? pnl, roi;
}

class AttachedOrderInput {
  const AttachedOrderInput({this.takeProfit, this.stopLoss});
  final AttachedExitInput? takeProfit, stopLoss;
}

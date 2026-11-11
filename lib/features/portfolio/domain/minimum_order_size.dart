import 'package:decimal/decimal.dart';

import 'futures_position_mode.dart';
import 'live_order.dart';
import 'live_order_size.dart';

/// Smallest input satisfying both quantity and notional filters at the current
/// references. The workspace shares one input across both direction buttons.
/// This is an input hint, never an execution or available-margin guarantee.
Decimal? minimumOrderSize({
  required LiveOrderContext context,
  required LiveOrderDraft draft,
  required OrderSizeUnit unit,
  bool bothDirections = false,
}) {
  if (draft.entireClose) return null;
  Decimal? minimum;
  final entries = bothDirections
      ? [draft.withDirection(true), draft.withDirection(false)]
      : [draft];
  for (final entry in entries) {
    final rule = context.rules.quantityRule(entry);
    if (rule.minimum <= Decimal.zero || rule.step <= Decimal.zero || rule.maximum < rule.minimum) {
      return null;
    }
    final pegReference = entry.peg == null ? null : context.referenceExecutionPrice(entry);
    if (entry.peg != null && pegReference == null) return null;
    var quantity = rule.minimum;
    if (!(entry.reducing && context.mode == FuturesPositionMode.oneWay) &&
        context.rules.minimumNotional > Decimal.zero) {
      final price = context.rules.notionalReference(
        entry,
        context.markPrice,
        pegReference: pegReference,
      );
      if (price == null || price <= Decimal.zero) return null;
      final needed = context.rules.minimumNotional / price;
      if (needed > quantity.toRational()) {
        final steps = ((needed - quantity.toRational()) / rule.step.toRational()).ceil();
        quantity += Decimal.fromBigInt(steps) * rule.step;
      }
    }
    if (quantity > rule.maximum) return null;
    final Decimal input;
    if (unit == OrderSizeUnit.quote) {
      final (reference, _) = orderSizeReference(context, entry);
      if (reference == null || reference <= Decimal.zero) return null;
      input = quantity * reference;
    } else {
      input = quantity;
    }
    if (minimum == null || input > minimum) minimum = input;
  }
  // The shared amount must also remain within both sides' maximum lot size.
  if (minimum != null && unit == OrderSizeUnit.quote) {
    for (final entry in entries) {
      final size = LiveOrderSize(unit: unit, text: '$minimum').resolve(context, entry);
      if (size.failure != null) return null;
    }
  }
  return minimum;
}

import 'package:decimal/decimal.dart';

import 'live_order.dart';

enum PositionTriggerInput { pnl, roi }

class PositionTriggerCalculation {
  const PositionTriggerCalculation({this.price, this.pnl, this.roi, this.failure});
  final Decimal? price, pnl, roi;
  final String? failure;
}

/// The input is an estimate target, not an instruction to place an order.
/// Round the exact rational price on the exchange's (price - min) lattice.
PositionTriggerCalculation calculatePositionTriggerPrice({
  required LiveOrderPosition? position,
  required Decimal? quantity,
  required int leverage,
  required LiveOrderRules rules,
  required PositionTriggerInput mode,
  required String input,
}) {
  if (position == null ||
      position.quantity == Decimal.zero ||
      position.entryPrice <= Decimal.zero ||
      quantity == null ||
      quantity <= Decimal.zero ||
      quantity > position.quantity.abs() ||
      leverage <= 0) {
    return const PositionTriggerCalculation(failure: 'triggerCalculationPosition');
  }
  if (input.length > 80 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(input)) {
    return const PositionTriggerCalculation(failure: 'triggerCalculationInput');
  }
  if (rules.priceTick <= Decimal.zero) {
    return const PositionTriggerCalculation(failure: 'triggerCalculationTick');
  }
  final value = Decimal.parse(input), direction = Decimal.fromInt(position.long ? 1 : -1);
  final entry = position.entryPrice;
  final raw =
      entry.toRational() +
      (mode == PositionTriggerInput.pnl
          ? value / (direction * quantity)
          : (entry * value) / (direction * Decimal.fromInt(leverage * 100)));
  if (raw <= Decimal.zero.toRational()) {
    return const PositionTriggerCalculation(failure: 'triggerCalculationBounds');
  }
  final steps = ((raw - rules.priceMinimum.toRational()) / rules.priceTick.toRational()).round();
  final price = rules.priceMinimum + Decimal.fromBigInt(steps) * rules.priceTick;
  if (price <= Decimal.zero || !rules.acceptsPrice(price) || price.toString().length > 80) {
    return const PositionTriggerCalculation(failure: 'triggerCalculationBounds');
  }
  final delta = direction * (price - entry);
  final roi = ((delta * Decimal.fromInt(leverage * 100)) / entry).toDecimal(
    scaleOnInfinitePrecision: entry.scale + price.scale + quantity.scale + 24,
    toBigInt: (value) => value.round(),
  );
  return PositionTriggerCalculation(price: price, pnl: delta * quantity, roi: roi);
}

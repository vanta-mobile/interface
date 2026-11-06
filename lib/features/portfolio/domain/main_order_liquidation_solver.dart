import 'package:rational/rational.dart';

import 'position_margin_adjustment.dart';

/// Each leg retains signed entry value; hedge legs have independent tiers.
class LiquidationLeg {
  const LiquidationLeg({required this.quantity, required this.entryValue});
  final Rational quantity, entryValue;
}

/// Solve equity(P) = maintenance(P) over every exact risk-tier interval.
/// Other contracts and collateral indices are held at their current values.
/// Positive collateral uses bid, liabilities ask; maintenance always uses ask.
Rational? solveMainOrderLiquidation({
  required List<LiquidationLeg> legs,
  required List<MarginRiskTier> tiers,
  required Rational wallet,
  required Rational otherEquityLessMaintenance,
  required Rational otherMaintenance,
  required Rational bidRate,
  required Rational askRate,
  required Rational mark,
}) {
  final zero = Rational.zero;
  final active = legs.where((p) => p.quantity != zero).toList();
  if (active.isEmpty ||
      tiers.isEmpty ||
      bidRate < zero ||
      askRate <= zero ||
      bidRate > askRate ||
      mark <= zero) {
    return null;
  }
  var nextFloor = zero, previousMm = zero;
  for (final tier in tiers) {
    final floor = tier.floor.toRational(),
        cap = tier.cap.toRational(),
        rate = tier.rate.toRational(),
        cum = tier.cumulative.toRational();
    if (floor != nextFloor ||
        cap <= floor ||
        rate < zero ||
        rate >= Rational.one ||
        cum < zero ||
        floor * rate - cum != previousMm) {
      return null;
    }
    nextFloor = cap;
    previousMm = cap * rate - cum;
  }
  // Merge tier boundaries for all legs rather than multiplying tier combinations.
  final boundaries = <Rational>{zero};
  for (final p in active) {
    for (final t in tiers) {
      boundaries.add(t.floor.toRational() / p.quantity.abs());
      boundaries.add(t.cap.toRational() / p.quantity.abs());
    }
  }
  final points = boundaries.toList()..sort();
  final signedQuantity = active.fold(zero, (v, p) => v + p.quantity);
  final entryValue = active.fold(zero, (v, p) => v + p.entryValue);
  final intercept = wallet - entryValue;
  final roots = <Rational>{};
  for (var i = 0; i + 1 < points.length; i++) {
    final lower = points[i], upper = points[i + 1], sample = (lower + upper) / Rational.fromInt(2);
    var rateQuantity = zero, cumulative = zero;
    var complete = true;
    for (final p in active) {
      final n = p.quantity.abs() * sample;
      final tier = tiers
          .where((t) => n >= t.floor.toRational() && n < t.cap.toRational())
          .singleOrNull;
      if (tier == null) {
        complete = false;
        break;
      }
      rateQuantity += p.quantity.abs() * tier.rate.toRational();
      cumulative += tier.cumulative.toRational();
    }
    if (!complete) continue;
    for (final positive in [true, false]) {
      final collateralRate = positive ? bidRate : askRate;
      final slope = signedQuantity * collateralRate - rateQuantity * askRate;
      final constant =
          otherEquityLessMaintenance +
          intercept * collateralRate +
          (cumulative - otherMaintenance) * askRate;
      if (slope == zero) continue;
      final root = -constant / slope;
      if (root <= zero || root < lower || root >= upper) continue;
      final equity = intercept + signedQuantity * root;
      if (positive ? equity < zero : equity > zero) continue;
      roots.add(root);
    }
  }
  if (roots.isEmpty) return null;
  // Hedge portfolios can have boundaries on either side. The nearer boundary
  // is the first risk crossing under this fixed-other-prices scenario.
  return roots.reduce((a, b) => (a - mark).abs() <= (b - mark).abs() ? a : b);
}

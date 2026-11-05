import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'live_order.dart';
import 'scaled_order_plan.dart';

/// Inclusive, distinct tick-aligned prices. Quantity weights follow the public
/// Aster form (1..n or powers of two); rounding and remainders are explicit
/// client rules. No platform Scaled strategy or atomic submission is implied.
ScaledOrderPlan planScaledOrder(LiveOrderContext context, ScaledOrderDraft draft) {
  if (draft.count < 2 || draft.count > 110) throw const AccountReadFailure('scaledCountInvalid');
  final low = parseOrderDecimal(draft.lowest), high = parseOrderDecimal(draft.highest);
  final size = parseOrderDecimal(draft.quantity), rules = context.rules;
  if (low == null || high == null || low <= Decimal.zero || high <= low) {
    throw const AccountReadFailure('scaledRangeInvalid');
  }
  if (rules.priceTick <= Decimal.zero || !rules.acceptsPrice(low) || !rules.acceptsPrice(high)) {
    throw const AccountReadFailure('liveOrderPriceFilter');
  }
  final span = (high - low) / rules.priceTick;
  if (!span.isInteger || span.floor() < BigInt.from(draft.count - 1)) {
    throw const AccountReadFailure('scaledRangeTooNarrow');
  }
  if (size == null || size <= Decimal.zero) {
    throw AccountReadFailure(
      draft.unit == ScaledSizeUnit.base ? 'liveOrderInvalidQuantity' : 'scaledAmountInvalid',
    );
  }
  final lot = rules.limitQuantity;
  if (lot.step <= Decimal.zero || lot.minimum <= Decimal.zero) {
    throw const AccountReadFailure('accountDataInvalid');
  }
  final prices = List.generate(
    draft.count,
    (i) =>
        low +
        Decimal.fromBigInt(span.floor() * BigInt.from(i) ~/ BigInt.from(draft.count - 1)) *
            rules.priceTick,
  );
  final weights = _weights(draft);
  final denominator = List.generate(
    draft.count,
    (i) => weights[i] * (draft.unit == ScaledSizeUnit.quote ? prices[i] : Decimal.one),
  ).fold(Decimal.zero, (sum, value) => sum + value);
  final ideals = weights.map((w) => size * w / denominator).toList();
  final steps = ideals.map((q) => (q - lot.minimum.toRational()) / lot.step.toRational()).toList();
  if (steps.any((s) => s < Decimal.zero.toRational())) {
    throw const AccountReadFailure('scaledQuantityTooSmall');
  }
  final whole = steps.map((s) => s.floor()).toList();
  if (draft.unit == ScaledSizeUnit.base) {
    final totalSteps = (size - lot.minimum * Decimal.fromInt(draft.count)) / lot.step;
    if (!totalSteps.isInteger) throw const AccountReadFailure('scaledQuantityStep');
    final remaining = totalSteps.floor() - whole.fold(BigInt.zero, (a, b) => a + b);
    // Largest fractional remainder; equal fractions go to lower prices first.
    final priority = List.generate(draft.count, (i) => i)
      ..sort((a, b) {
        final compared = (steps[b] - Decimal.fromBigInt(whole[b]).toRational()).compareTo(
          steps[a] - Decimal.fromBigInt(whole[a]).toRational(),
        );
        return compared == 0 ? a.compareTo(b) : compared;
      });
    for (var i = 0; i < remaining.toInt(); i++) {
      whole[priority[i]] += BigInt.one;
    }
  }
  final quantities = whole.map((s) => lot.minimum + Decimal.fromBigInt(s) * lot.step).toList();
  if (draft.distribution == ScaledDistribution.random) _checkVariance(draft, quantities);
  final orders = List.generate(draft.count, (i) {
    final order = LiveOrderDraft(
      buy: draft.buy,
      market: false,
      quantity: '${quantities[i]}',
      price: '${prices[i]}',
    );
    final failure = context.validate(order);
    if (failure != null) throw AccountReadFailure(failure);
    return order;
  });
  return ScaledOrderPlan(draft: draft, orders: orders);
}

List<Decimal> _weights(ScaledOrderDraft draft) {
  if (draft.distribution == ScaledDistribution.random) {
    final variance = parseOrderDecimal(draft.variance), seed = draft.randomSeed;
    if (variance == null || variance < Decimal.zero || variance > Decimal.fromInt(10)) {
      throw const AccountReadFailure('scaledVarianceInvalid');
    }
    if (seed == null || seed < 0 || seed > 0xffffffff) {
      throw const AccountReadFailure('scaledRandomRequired');
    }
    // Paired integer perturbations sum to zero, keeping every target weight
    // within the entered percentage of the mean. Integer PRNG is reproducible.
    var state = seed;
    final weights = List.filled(draft.count, Decimal.fromInt(10000));
    for (var i = 0; i + 1 < draft.count; i += 2) {
      state = (1664525 * state + 1013904223) & 0xffffffff;
      final signed = state % 20001 - 10000;
      final delta = (variance * Decimal.fromInt(signed) / Decimal.fromInt(100)).toDecimal();
      weights[i] += delta;
      weights[i + 1] -= delta;
    }
    // Shuffle paired weights without changing their sum or bounds.
    for (var i = weights.length - 1; i > 0; i--) {
      state = (1664525 * state + 1013904223) & 0xffffffff;
      final j = state % (i + 1), saved = weights[i];
      weights[i] = weights[j];
      weights[j] = saved;
    }
    return weights;
  }
  return List.generate(draft.count, (i) {
    if (draft.distribution == ScaledDistribution.equal) return Decimal.one;
    final index = draft.distribution == ScaledDistribution.decreasing ? draft.count - i - 1 : i;
    return draft.constant == ScaledConstant.difference
        ? Decimal.fromInt(index + 1)
        : Decimal.fromBigInt(BigInt.one << index);
  });
}

void _checkVariance(ScaledOrderDraft draft, List<Decimal> quantities) {
  final total = quantities.fold(Decimal.zero, (a, b) => a + b);
  final variance = parseOrderDecimal(draft.variance)!;
  for (final quantity in quantities) {
    final deviation = (quantity * Decimal.fromInt(draft.count) - total).abs();
    if (deviation * Decimal.fromInt(100) > total * variance) {
      throw const AccountReadFailure('scaledVarianceStep');
    }
  }
}

import 'package:decimal/decimal.dart';

import 'live_order.dart';
import 'live_order_time_in_force.dart';

enum ScaledSizeUnit { base, quote }

enum ScaledDistribution { equal, increasing, decreasing, random }

enum ScaledConstant { difference, ratio }

/// Local intent. Randomness is captured as a public seed before review, so
/// rebuilding, validating, submitting and recovering never resample a plan.
class ScaledOrderDraft {
  const ScaledOrderDraft({
    required this.buy,
    required this.lowest,
    required this.highest,
    required this.quantity,
    required this.count,
    this.unit = ScaledSizeUnit.base,
    this.distribution = ScaledDistribution.equal,
    this.constant = ScaledConstant.difference,
    this.variance = '10',
    this.randomSeed,
    this.reduceOnly = false,
    this.timeInForce = LiveOrderTimeInForce.gtc,
  });
  final bool buy;
  final String lowest, highest, quantity, variance;
  final int count;
  final ScaledSizeUnit unit;
  final ScaledDistribution distribution;
  final ScaledConstant constant;
  final int? randomSeed;

  /// Applied to every child order; GTC, IOC or Hidden.
  final bool reduceOnly;
  final LiveOrderTimeInForce timeInForce;
  bool get progressive =>
      distribution == ScaledDistribution.increasing ||
      distribution == ScaledDistribution.decreasing;

  @override
  bool operator ==(Object other) =>
      other is ScaledOrderDraft &&
      buy == other.buy &&
      lowest == other.lowest &&
      highest == other.highest &&
      quantity == other.quantity &&
      count == other.count &&
      unit == other.unit &&
      distribution == other.distribution &&
      constant == other.constant &&
      variance == other.variance &&
      randomSeed == other.randomSeed &&
      reduceOnly == other.reduceOnly &&
      timeInForce == other.timeInForce;
  @override
  int get hashCode => Object.hash(
    buy,
    lowest,
    highest,
    quantity,
    count,
    unit,
    distribution,
    constant,
    variance,
    randomSeed,
    reduceOnly,
    timeInForce,
  );
}

class ScaledOrderPlan {
  ScaledOrderPlan({required this.draft, required Iterable<LiveOrderDraft> orders})
    : orders = List.unmodifiable(orders);
  final ScaledOrderDraft draft;
  final List<LiveOrderDraft> orders;
  Decimal get totalQuantity =>
      orders.fold(Decimal.zero, (sum, o) => sum + parseOrderDecimal(o.quantity)!);
  Decimal get notional => orders.fold(
    Decimal.zero,
    (sum, o) => sum + parseOrderDecimal(o.quantity)! * parseOrderDecimal(o.price)!,
  );
  Decimal? get unallocatedQuote =>
      draft.unit == ScaledSizeUnit.quote ? parseOrderDecimal(draft.quantity)! - notional : null;
}

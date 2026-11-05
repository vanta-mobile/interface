import 'package:decimal/decimal.dart';

import 'live_order_opening_cost.dart';
import 'live_order_rules.dart';

/// An anonymous, symbol-level open-interest constraint, not a personal budget.
/// Null remaining is the documented -1 sentinel, never missing/failed data.
class SymbolOpenableNotional {
  const SymbolOpenableNotional({
    required this.symbol,
    required this.leverage,
    required this.receivedAt,
    required this.remaining,
  });
  final String symbol;
  final int leverage;
  final DateTime receivedAt;
  final Decimal? remaining;
  bool get unlimited => remaining == null;
}

/// Exact sizing kernel for an already assembled and validated account/market
/// snapshot. Margin must already include the selected asset/margin mode's
/// restrictions; a USDT account summary is not a multi-asset valuation.
///
/// This model does not fetch, refresh, sign, or assert exchange acceptance.
class LiveOrderCapacity {
  LiveOrderCapacity({
    required this.exposure,
    required this.availableMargin,
    required this.notionalCap,
    required this.remainingOpenableNotional,
    required this.rule,
    required this.minimumNotional,
  }) {
    if (notionalCap <= Decimal.zero ||
        remainingOpenableNotional != null && remainingOpenableNotional! < Decimal.zero ||
        rule.minimum <= Decimal.zero ||
        rule.maximum < rule.minimum ||
        rule.step <= Decimal.zero ||
        minimumNotional < Decimal.zero) {
      throw ArgumentError('Invalid order capacity');
    }
  }

  final LiveOrderOpeningExposure exposure;
  final Decimal availableMargin, notionalCap, minimumNotional;
  final Decimal? remainingOpenableNotional;
  final OrderQuantityRule rule;

  LiveOrderSideCapacity side({
    required bool buy,
    required Decimal marginPrice,
    required Decimal lossPrice,
    required Decimal conversionPrice,
    required Decimal notionalPrice,
  }) {
    if ([marginPrice, lossPrice, conversionPrice, notionalPrice].any((v) => v <= Decimal.zero)) {
      throw ArgumentError('Invalid capacity price');
    }
    // Never turn negative free margin into new spending. Zero-cost reductions
    // may still be possible, without budgeting released margin or future fills.
    final budget = (availableMargin > Decimal.zero ? availableMargin : Decimal.zero).toRational();
    // If a changed bracket is below current exposure, a non-increasing order
    // may still reduce it. No order may increase the existing excess.
    final riskCap = notionalCap > exposure.currentNotional ? notionalCap : exposure.currentNotional;
    bool fits(Decimal quantity) {
      final cost = exposure.cost(
        buy: buy, quantity: quantity, marginPrice: marginPrice, lossPrice: lossPrice,
      );
      return cost.total <= budget &&
          cost.notionalAfter <= riskCap &&
          (remainingOpenableNotional == null ||
              cost.openingQuantity * marginPrice <= remainingOpenableNotional!);
    }

    // Cost and risk predicates are monotone on nonnegative quantity: shrinking
    // the current opposite exposure costs zero before any incremental increase.
    // Search exact exchange steps, with BigInt even beyond double precision.
    var low = BigInt.zero;
    var high = ((rule.maximum - rule.minimum) / rule.step).floor() + BigInt.one;
    while (low < high) {
      final middle = (low + high + BigInt.one) ~/ BigInt.two;
      final quantity = rule.minimum + Decimal.fromBigInt(middle - BigInt.one) * rule.step;
      if (fits(quantity)) {
        low = middle;
      } else {
        high = middle - BigInt.one;
      }
    }
    var maximum = low == BigInt.zero
        ? Decimal.zero
        : rule.minimum + Decimal.fromBigInt(low - BigInt.one) * rule.step;
    if (maximum * notionalPrice < minimumNotional) maximum = Decimal.zero;
    return LiveOrderSideCapacity(
      buy: buy, maximum: maximum, conversionPrice: conversionPrice, rule: rule,
    );
  }
}

class LiveOrderSideCapacity {
  const LiveOrderSideCapacity({
    required this.buy,
    required this.maximum,
    required this.conversionPrice,
    required this.rule,
  });
  final bool buy;
  final Decimal maximum, conversionPrice;
  final OrderQuantityRule rule;
  Decimal get maximumQuote => maximum * conversionPrice;

  /// Zero percent is a valid blank-input initial selection at the UI boundary.
  /// Tiny allocations stay zero; never increase them to the exchange minimum.
  Decimal quantityAt(int percent) {
    if (percent < 0 || percent > 100) throw ArgumentError('Invalid order percentage');
    final raw = maximum.toRational() * Decimal.fromInt(percent).toRational() /
        Decimal.fromInt(100).toRational();
    if (raw < rule.minimum.toRational()) return Decimal.zero;
    return rule.minimum + Decimal.fromBigInt(
      ((raw - rule.minimum.toRational()) / rule.step.toRational()).floor(),
    ) * rule.step;
  }
}

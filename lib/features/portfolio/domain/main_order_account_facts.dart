import 'package:decimal/decimal.dart';

import 'aster_open_orders.dart';
import 'position_margin_adjustment.dart';

/// The account-wide facts needed to recompute sizing after a price change.
/// An empty order list is meaningful only after an unscoped signed read.
class MainOrderAccountFacts {
  MainOrderAccountFacts({
    required this.orders,
    required Map<String, List<MarginRiskTier>> riskTiers,
    this.takerFee,
  }) : riskTiers = Map.unmodifiable({
         for (final e in riskTiers.entries) e.key: List<MarginRiskTier>.unmodifiable(e.value),
       });
  final AsterOpenOrders orders;
  final Map<String, List<MarginRiskTier>> riskTiers;

  /// Actual symbol-specific signed rate; absent never means a zero fee.
  final Decimal? takerFee;
}

import 'package:decimal/decimal.dart';

import 'aster_account.dart';

/// Every term must come from the same signed account position, never a public
/// mark estimate mixed with a maintenance requirement from another read.
({Decimal? percent, bool atRisk}) isolatedMarginRatio(AsterPosition p) {
  final wallet = p.isolatedWallet, pnl = p.unrealizedProfit, maintenance = p.maintenanceMargin;
  if (p.isolated != true ||
      wallet == null ||
      pnl == null ||
      maintenance == null ||
      maintenance < Decimal.zero) {
    return (percent: null, atRisk: false);
  }
  final equity = wallet + pnl;
  if (equity <= Decimal.zero) return (percent: null, atRisk: true);
  return (
    percent: (maintenance * Decimal.fromInt(100) / equity).toDecimal(scaleOnInfinitePrecision: 24),
    atRisk: false,
  );
}

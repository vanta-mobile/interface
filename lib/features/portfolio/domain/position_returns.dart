import 'package:decimal/decimal.dart';

import 'position_risk.dart';

/// Linear-contract display estimates, not available funds or a liquidation
/// model. ROE uses initial margin even for isolated positions; the isolated
/// wallet remains a separate allocation and may include added margin.
class PositionReturns {
  factory PositionReturns({
    required PositionRisk position,
    required Decimal? mark,
    required Decimal? pnl,
  }) {
    Decimal? margin = position.isolated ? position.isolatedWallet : null;
    final units = position.units;
    final leverage = position.leverage;
    if (position.balanceOnly ||
        units == null ||
        units.margin != units.quote ||
        leverage == null ||
        leverage <= 0 ||
        mark == null ||
        mark <= Decimal.zero) {
      return PositionReturns._(margin, null, null);
    }
    final notional = (position.quantity * mark).abs();
    final divisor = Decimal.fromInt(leverage);
    // Retain exact rational division until the display boundary. For
    // repeating values, preserve tiny notionals rather than rounding to zero.
    final initialMargin = (notional / divisor).toDecimal(
      scaleOnInfinitePrecision: notional.scale + 24,
      toBigInt: (value) => value.round(),
    );
    if (!position.isolated) margin = initialMargin;
    if (pnl == null || position.entryPrice <= Decimal.zero) {
      return PositionReturns._(margin, initialMargin, null);
    }
    // Quantize the final percentage to two places, half away from zero.
    // Never divide by a rounded margin or use double arithmetic.
    final hundredths = ((pnl * divisor * Decimal.fromInt(10000)) / notional).round();
    return PositionReturns._(
      margin,
      initialMargin,
      Decimal.fromBigInt(hundredths) * Decimal.parse('0.01'),
    );
  }

  const PositionReturns._(this.margin, this.initialMargin, this.roePercent);
  final Decimal? margin, initialMargin, roePercent;
}

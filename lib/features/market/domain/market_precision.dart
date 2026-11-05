import 'package:decimal/decimal.dart';

/// Exchange increments are decimal values, independent of display rounding.
class MarketPrecision {
  const MarketPrecision({this.priceTick, this.quantityStep});
  final String? priceTick, quantityStep;
  int get priceDecimals => _scale(priceTick);
  int get quantityDecimals => quantityStep == null ? 5 : _scale(quantityStep);
  static int _scale(String? value) => Decimal.tryParse(value ?? '')?.scale ?? 0;

  factory MarketPrecision.fromExchange(Map<String, dynamic> symbol) {
    String? increment(String type, String field) {
      for (final filter in (symbol['filters'] as List<dynamic>? ?? const [])) {
        if (filter is! Map<String, dynamic> || filter['filterType'] != type) continue;
        final value = Decimal.tryParse('${filter[field]}');
        if (value != null && value > Decimal.zero) return value.toString();
      }
      return null;
    }

    return MarketPrecision(
      priceTick: increment('PRICE_FILTER', 'tickSize'),
      quantityStep: increment('LOT_SIZE', 'stepSize'),
    );
  }

  bool acceptsPrice(Decimal value) => _aligned(value, priceTick);
  bool acceptsQuantity(Decimal value) => _aligned(value, quantityStep ?? '0.00001');
  bool _aligned(Decimal value, String? step) =>
      step == null || value % Decimal.parse(step) == Decimal.zero;
  Decimal floorQuantity(Decimal value) {
    final step = Decimal.parse(quantityStep ?? '0.00001');
    final count = (value / step).floor();
    return Decimal.fromBigInt(count) * step;
  }
}

/// Keep supplied decimal digits, including very small prices. Integers have no
/// decimal suffix; fractions have at least two places. This also preserves the
/// second nonzero fractional digit even when zeros occur between the digits.
String marketNumber(Object value, {int minimumDecimals = 0, bool grouping = true}) {
  final decimal = value is Decimal ? value : Decimal.tryParse('$value');
  if (decimal == null) return '—';
  final parts = decimal.toString().split('.');
  var integer = parts.first;
  if (grouping) {
    integer = integer.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
  if (parts.length == 1) return integer;
  final fraction = parts.last.padRight(minimumDecimals > 2 ? minimumDecimals : 2, '0');
  return '$integer.$fraction';
}

String marketInput(Object value) => marketNumber(value, grouping: false, minimumDecimals: 0);

int marketDrawingDecimals(Iterable<double> values, {int minimum = 0}) {
  var result = minimum;
  for (final value in values) {
    final decimal = Decimal.tryParse('$value');
    if (decimal != null && decimal.scale > result) result = decimal.scale;
  }
  return result.clamp(0, 20);
}

Decimal marketAllocation({
  required Decimal available,
  required Decimal fraction,
  required Decimal price,
  required int leverage,
  required Decimal feeRate,
  required MarketPrecision precision,
}) {
  if (price <= Decimal.zero || leverage < 1) return Decimal.zero;
  final step = Decimal.parse(precision.quantityStep ?? '0.00001');
  final perUnit =
      price.toRational() / Decimal.fromInt(leverage).toRational() + (price * feeRate).toRational();
  final count = ((available * fraction).toRational() / perUnit / step.toRational()).floor();
  return Decimal.fromBigInt(count) * step;
}

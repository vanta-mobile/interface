final class DecimalValue {
  factory DecimalValue(String value, {String? asset, String? unit, int? scale}) {
    if (!_syntax.hasMatch(value)) {
      throw FormatException('Invalid decimal value');
    }
    final fraction = !value.contains('.') ? 0 : value.length - value.indexOf('.') - 1;
    if (scale != null && scale != fraction) {
      throw FormatException('Decimal scale does not match the value');
    }
    return DecimalValue._(value, asset: asset, unit: unit, scale: scale ?? fraction);
  }

  const DecimalValue._(this.value, {this.asset, this.unit, required this.scale});

  static final RegExp _syntax = RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?$');

  final String value;
  final String? asset;
  final String? unit;
  final int scale;

  int compareTo(DecimalValue other) {
    if (asset != other.asset || unit != other.unit) {
      throw ArgumentError('Cannot compare different decimal units');
    }
    return compareMagnitudeTo(other);
  }

  /// Compares values for the same asset while ignoring presentation/semantic
  /// units such as `token`, `notional`, or `fee`.
  int compareMagnitudeTo(DecimalValue other) {
    if (asset != other.asset) {
      throw ArgumentError('Cannot compare different decimal assets');
    }
    final commonScale = scale > other.scale ? scale : other.scale;
    final left = _scaledInteger(commonScale);
    final right = other._scaledInteger(commonScale);
    return left.compareTo(right);
  }

  DecimalValue plus(DecimalValue other) {
    if (asset != other.asset || unit != other.unit) {
      throw ArgumentError('Cannot add different decimal units');
    }
    return plusMagnitude(other);
  }

  /// Adds values for the same asset while ignoring semantic units.
  DecimalValue plusMagnitude(DecimalValue other) {
    if (asset != other.asset) {
      throw ArgumentError('Cannot add different decimal assets');
    }
    final commonScale = scale > other.scale ? scale : other.scale;
    final sum = _scaledInteger(commonScale) + other._scaledInteger(commonScale);
    final negative = sum.isNegative;
    final digits = sum.abs().toString().padLeft(commonScale + 1, '0');
    final split = digits.length - commonScale;
    final value = commonScale == 0
        ? digits
        : '${digits.substring(0, split)}.${digits.substring(split)}';
    return DecimalValue(
      '${negative ? '-' : ''}$value',
      asset: asset,
      unit: unit,
      scale: commonScale,
    );
  }

  BigInt _scaledInteger(int targetScale) {
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final digits = '${parts.first}${parts.length == 1 ? '' : parts.last}'.padRight(
      parts.first.length + targetScale,
      '0',
    );
    final integer = BigInt.parse(digits);
    return negative ? -integer : integer;
  }

  @override
  bool operator ==(Object other) =>
      other is DecimalValue &&
      value == other.value &&
      asset == other.asset &&
      unit == other.unit &&
      scale == other.scale;

  @override
  int get hashCode => Object.hash(value, asset, unit, scale);

  @override
  String toString() => value;
}

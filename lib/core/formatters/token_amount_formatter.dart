import '../domain/decimal_value.dart';

enum TokenAmountDisplay { exact, normalized }

/// Formats token amounts without converting them to binary floating point.
abstract final class TokenAmountFormatter {
  /// Displays at most six fractional digits, or six digits starting at the
  /// first non-zero fractional digit when the absolute value is below one.
  /// Rounds half away from zero and trims trailing fractional zeros.
  static String formatDecimal(DecimalValue amount) =>
      _groupIntegerDigits(_formatAdaptiveDecimal(amount.value));

  /// Formats only the numeric portion of a decimal amount for display.
  ///
  /// The token's decimal limit is validated first, then the shared adaptive
  /// display precision is applied. Use [formatFixed] for editable fields that
  /// must retain an exact scale.
  static String formatValue(DecimalValue amount, {int? decimals}) {
    if (decimals != null) _validateDecimals(decimals);
    return _groupIntegerDigits(_formatAdaptiveDecimal(_enforceDecimals(amount.value, decimals)));
  }

  /// Formats a server-provided decimal string for a display label. Non-decimal
  /// placeholders are returned unchanged so this is safe for optional labels.
  static String formatText(String value) {
    try {
      return formatDecimal(DecimalValue(value));
    } on FormatException {
      return value;
    }
  }

  /// Formats USD values with at most two fractional digits, while preserving
  /// sub-dollar precision so small balances do not collapse to `$0`.
  static String formatUsd(DecimalValue amount) {
    final absoluteValue = amount.value.startsWith('-') ? amount.value.substring(1) : amount.value;
    final integerPart = absoluteValue.split('.').first;
    final formatted = integerPart == '0'
        ? _formatAdaptiveDecimal(amount.value)
        : _trimInsignificantZeros(_roundToFractionDigits(amount.value, 2));
    return '\$${_groupIntegerDigits(formatted)}';
  }

  /// Formats USD values with an exact number of fractional digits.
  ///
  /// This is intended for compact price/value labels where unrestricted
  /// sub-dollar precision would overflow the available layout. When
  /// [preserveSmallValues] is enabled, a non-zero value that would round to
  /// zero uses the shared adaptive precision instead. Adaptive precision keeps
  /// at most six digits beginning with the first non-zero fractional digit.
  static String formatUsdFixed(
    DecimalValue amount, {
    int fractionDigits = 2,
    bool preserveSmallValues = false,
  }) {
    _validateDecimals(fractionDigits);
    final rounded = _roundToFractionDigits(amount.value, fractionDigits);
    if (preserveSmallValues && _isZeroDecimal(rounded) && !_isZeroDecimal(amount.value)) {
      return formatUsd(amount);
    }
    final fixed = _padFractionDigits(rounded, fractionDigits);
    return '\$${_groupIntegerDigits(fixed)}';
  }

  /// Formats large values with a compact uppercase suffix while preserving
  /// decimal precision without converting through binary floating point.
  static String formatCompact(DecimalValue amount, {bool usd = false}) {
    final negative = amount.value.startsWith('-');
    final unsigned = negative ? amount.value.substring(1) : amount.value;
    final integerDigits = unsigned.split('.').first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final digits = integerDigits.isEmpty ? '0' : integerDigits;
    final suffix = switch (digits.length) {
      >= 13 => (scale: 12, label: 'T'),
      >= 10 => (scale: 9, label: 'B'),
      >= 7 => (scale: 6, label: 'M'),
      >= 4 => (scale: 3, label: 'K'),
      _ => (scale: 0, label: ''),
    };
    if (suffix.scale == 0) {
      final value = _formatAdaptiveDecimal(unsigned);
      return '${negative ? '-' : ''}${usd ? '\$' : ''}$value';
    }

    final scaled = _divideDecimalByPower(unsigned, suffix.scale);
    final compact = _trimInsignificantZeros(_roundToFractionDigits(scaled, 2));
    return '${negative ? '-' : ''}${usd ? '\$' : ''}$compact${suffix.label}';
  }

  /// Formats a grouped display value rounded half away from zero to at most
  /// [maxFractionDigits], trimming trailing fractional zeros. A non-zero value
  /// that would round to zero keeps the shared adaptive precision instead.
  static String formatRounded(DecimalValue amount, {required int maxFractionDigits}) {
    _validateDecimals(maxFractionDigits);
    final rounded = _roundToFractionDigits(amount.value, maxFractionDigits);
    if (_isZeroDecimal(rounded) && !_isZeroDecimal(amount.value)) {
      return formatDecimal(amount);
    }
    final trimmed = _trimInsignificantZeros(rounded);
    return _groupIntegerDigits(trimmed == '-0' ? '0' : trimmed);
  }

  /// Formats a percentage for display with at most two fractional digits.
  ///
  /// Market API values can contain high-precision decimal values, which are
  /// useful for calculations but are not appropriate for compact UI labels.
  static String formatPercent(
    DecimalValue amount, {
    bool signed = true,
    int maxFractionDigits = 2,
    bool trimInsignificantZeros = true,
    bool preserveSmallValues = false,
  }) {
    _validateDecimals(maxFractionDigits);
    final fixed = _roundToFractionDigits(amount.value, maxFractionDigits);
    final rounded = preserveSmallValues && _isZeroDecimal(fixed) && !_isZeroDecimal(amount.value)
        ? _formatAdaptiveDecimal(amount.value)
        : fixed;
    final normalized = _groupIntegerDigits(
      trimInsignificantZeros
          ? _trimInsignificantZeros(rounded)
          : _padFractionDigits(rounded, maxFractionDigits),
    );
    if (!signed || normalized.startsWith('-') || normalized == '0') {
      return '$normalized%';
    }
    return '+$normalized%';
  }

  /// Formats a decimal for an editable financial field without adding a
  /// currency or token symbol. This keeps feature widgets from implementing
  /// their own rounding or zero-padding rules.
  static String formatFixed(DecimalValue amount, {required int decimals, bool grouping = false}) {
    _validateDecimals(decimals);
    final value = _enforceDecimals(amount.value, decimals);
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final integer = parts.first;
    final fraction = parts.length == 1 ? '' : parts.last;
    final fixed = decimals == 0 ? integer : '$integer.${fraction.padRight(decimals, '0')}';
    final signed = '${negative ? '-' : ''}$fixed';
    return grouping ? _groupIntegerDigits(signed) : signed;
  }

  /// Adds USD decimal values without passing through binary floating point.
  static String sumUsd(Iterable<DecimalValue?> amounts) {
    final total = _sum(amounts);
    return total == null ? '—' : formatUsd(total);
  }

  /// Adds and fixed-formats USD values without binary floating point.
  static String sumUsdFixed(Iterable<DecimalValue?> amounts, {int fractionDigits = 2}) {
    final total = _sum(amounts);
    return total == null ? '—' : formatUsdFixed(total, fractionDigits: fractionDigits);
  }

  static DecimalValue? _sum(Iterable<DecimalValue?> amounts) {
    final values = amounts.whereType<DecimalValue>().toList(growable: false);
    if (values.isEmpty) return null;
    final scale = values.fold<int>(
      0,
      (current, value) => current > value.scale ? current : value.scale,
    );
    var sum = BigInt.zero;
    for (final value in values) {
      final negative = value.value.startsWith('-');
      final raw = negative ? value.value.substring(1) : value.value;
      final parts = raw.split('.');
      final digits = '${parts.first}${parts.length == 1 ? '' : parts.last}'.padRight(
        parts.first.length + scale,
        '0',
      );
      final parsed = BigInt.parse(digits);
      sum += negative ? -parsed : parsed;
    }
    final negative = sum.isNegative;
    final digits = sum.abs().toString().padLeft(scale + 1, '0');
    final value = scale == 0
        ? '${negative ? '-' : ''}$digits'
        : '${negative ? '-' : ''}'
              '${digits.substring(0, digits.length - scale)}.'
              '${digits.substring(digits.length - scale)}';
    return DecimalValue(value);
  }

  static String format(
    DecimalValue amount, {
    required String symbol,
    int? decimals,
    TokenAmountDisplay display = TokenAmountDisplay.normalized,
  }) {
    final normalizedSymbol = symbol.trim();
    if (normalizedSymbol.isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'Must not be empty');
    }
    _validateAsset(amount, normalizedSymbol);
    final effectiveValue = _enforceDecimals(amount.value, decimals);
    final displayedValue = switch (display) {
      TokenAmountDisplay.exact => effectiveValue,
      TokenAmountDisplay.normalized => _formatAdaptiveDecimal(effectiveValue),
    };
    return '${_groupIntegerDigits(displayedValue)} $normalizedSymbol';
  }

  /// Converts an integer amount in the token's smallest unit and formats it.
  static String formatAtomic(
    BigInt atomicUnits, {
    required String symbol,
    required int decimals,
    TokenAmountDisplay display = TokenAmountDisplay.normalized,
  }) {
    _validateDecimals(decimals);
    final negative = atomicUnits.isNegative;
    final digits = atomicUnits.abs().toString().padLeft(decimals + 1, '0');
    final value = decimals == 0
        ? '${negative ? '-' : ''}$digits'
        : '${negative ? '-' : ''}'
              '${digits.substring(0, digits.length - decimals)}.'
              '${digits.substring(digits.length - decimals)}';
    return format(
      DecimalValue(value, asset: symbol, unit: 'token'),
      symbol: symbol,
      decimals: decimals,
      display: display,
    );
  }

  static void _validateAsset(DecimalValue amount, String symbol) {
    final asset = amount.asset?.trim();
    if (asset != null && asset.isNotEmpty && asset.toUpperCase() != symbol.toUpperCase()) {
      throw ArgumentError.value(symbol, 'symbol', 'Does not match DecimalValue.asset');
    }
  }

  static String _enforceDecimals(String value, int? decimals) {
    if (decimals == null) return value;
    _validateDecimals(decimals);
    final separator = value.indexOf('.');
    if (separator == -1) return value;
    final fraction = value.substring(separator + 1);
    if (fraction.length <= decimals) return value;
    final excess = fraction.substring(decimals);
    if (excess.contains(RegExp('[1-9]'))) {
      throw FormatException('Amount precision exceeds token decimals without rounding permission');
    }
    if (decimals == 0) return value.substring(0, separator);
    return value.substring(0, separator + 1 + decimals);
  }

  static void _validateDecimals(int decimals) {
    if (decimals < 0) {
      throw RangeError.range(decimals, 0, null, 'decimals');
    }
  }

  static String _trimInsignificantZeros(String value) {
    if (!value.contains('.')) return value;
    final withoutZeros = value.replaceFirst(RegExp(r'0+$'), '');
    return withoutZeros.endsWith('.')
        ? withoutZeros.substring(0, withoutZeros.length - 1)
        : withoutZeros;
  }

  static bool _isZeroDecimal(String value) =>
      BigInt.parse(value.replaceFirst('-', '').replaceAll('.', '')) == BigInt.zero;

  static String _formatAdaptiveDecimal(String value) {
    final unsigned = value.startsWith('-') ? value.substring(1) : value;
    final parts = unsigned.split('.');
    var fractionDigits = 6;
    if (parts.first == '0' && parts.length > 1) {
      final firstNonZero = parts.last.indexOf(RegExp('[1-9]'));
      if (firstNonZero == -1) return '0';
      fractionDigits += firstNonZero;
    }
    final rounded = _trimInsignificantZeros(_roundToFractionDigits(value, fractionDigits));
    return rounded == '-0' ? '0' : rounded;
  }

  static String _padFractionDigits(String value, int fractionDigits) {
    if (fractionDigits == 0) return value;
    final separator = value.indexOf('.');
    if (separator == -1) return '$value.${'0' * fractionDigits}';
    final fraction = value.substring(separator + 1);
    return fraction.length >= fractionDigits
        ? value
        : '$value${'0' * (fractionDigits - fraction.length)}';
  }

  static String _roundToFractionDigits(String value, int maxFractionDigits) {
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final integer = parts.first;
    final fraction = parts.length == 1 ? '' : parts.last;
    if (fraction.length <= maxFractionDigits) return value;

    final retainedFraction = fraction.substring(0, maxFractionDigits);
    var scaled = BigInt.parse('$integer$retainedFraction');
    if (fraction[maxFractionDigits].compareTo('5') >= 0) {
      scaled += BigInt.one;
    }

    final digits = scaled.toString().padLeft(maxFractionDigits + 1, '0');
    final rounded = maxFractionDigits == 0
        ? digits
        : '${digits.substring(0, digits.length - maxFractionDigits)}.'
              '${digits.substring(digits.length - maxFractionDigits)}';
    if (scaled == BigInt.zero) return rounded;
    return '${negative ? '-' : ''}$rounded';
  }

  static String _divideDecimalByPower(String value, int power) {
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final digits = unsigned.replaceFirst('.', '');
    final decimalPlaces = unsigned.contains('.') ? unsigned.length - unsigned.indexOf('.') - 1 : 0;
    final targetPlaces = power + decimalPlaces;
    final padded = digits.padLeft(targetPlaces + 1, '0');
    final split = padded.length - targetPlaces;
    final result = '${padded.substring(0, split)}.${padded.substring(split)}';
    return '${negative ? '-' : ''}$result';
  }

  static String _groupIntegerDigits(String value) {
    final negative = value.startsWith('-');
    final unsigned = negative ? value.substring(1) : value;
    final separator = unsigned.indexOf('.');
    final integer = separator == -1 ? unsigned : unsigned.substring(0, separator);
    final fraction = separator == -1 ? '' : unsigned.substring(separator);
    final grouped = integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${negative ? '-' : ''}$grouped$fraction';
  }
}

import 'package:decimal/decimal.dart';

import '../domain/position_leverage.dart';
import 'position_configuration_rows.dart';

void validateLeverageSymbol(String symbol) {
  validatePositionSymbol(symbol);
}

/// PositionRisk includes zero-sized configuration rows. Do not use the
/// portfolio mapper which deliberately removes those rows from positions.
int mapCurrentLeverage(Object? payload, String symbol) {
  int? leverage;
  for (final row in positionConfigurationRows(payload, symbol)) {
    final raw = row['leverage'];
    final value = raw is String && RegExp(r'^[1-9]\d{0,3}$').hasMatch(raw) ? int.parse(raw) : null;
    if (value == null || (leverage != null && leverage != value)) {
      throw const FormatException('Conflicting configuration');
    }
    leverage = value;
  }
  return leverage!;
}

List<LeverageBracket> mapLeverageBrackets(Object? payload, String symbol) {
  // The symbol-scoped endpoint documents an object; tolerate its documented
  // array variant only when it contains exactly the requested symbol.
  final data = payload is List && payload.length == 1 ? payload.single : payload;
  if (data is! Map<String, dynamic> ||
      data['symbol'] != symbol ||
      data['brackets'] is! List ||
      (data['brackets'] as List).isEmpty) {
    throw const FormatException('Invalid brackets');
  }
  Decimal amount(Object? value) {
    // JSON integer notionals are exact; floating-point financial values are
    // not accepted. Decimal strings also preserve all supplied precision.
    if (value is! String && value is! int) throw const FormatException('Invalid notional');
    final text = '$value';
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) throw const FormatException('Invalid notional');
    return Decimal.parse(text);
  }

  final result = <LeverageBracket>[];
  for (final row in data['brackets'] as List) {
    if (row is! Map<String, dynamic>) throw const FormatException('Invalid bracket');
    int whole(Object? value) {
      if (value is int) return value;
      if (value is String && RegExp(r'^[1-9]\d{0,3}$').hasMatch(value)) {
        return int.parse(value);
      }
      throw const FormatException('Invalid bracket integer');
    }

    if (whole(row['bracket']) != result.length + 1) {
      throw const FormatException('Invalid bracket');
    }
    final maximum = whole(row['initialLeverage']);
    final floor = amount(row['notionalFloor']), cap = amount(row['notionalCap']);
    if (maximum < 1 ||
        maximum > 9999 ||
        cap <= floor ||
        floor != (result.isEmpty ? Decimal.zero : result.last.cap) ||
        result.isNotEmpty && maximum > result.last.maximum) {
      throw const FormatException('Inconsistent brackets');
    }
    result.add(LeverageBracket(maximum: maximum, floor: floor, cap: cap));
  }
  return List.unmodifiable(result);
}

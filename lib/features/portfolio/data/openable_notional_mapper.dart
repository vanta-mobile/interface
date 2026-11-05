import 'package:decimal/decimal.dart';

import '../domain/live_order_capacity.dart';
import 'position_configuration_rows.dart';

SymbolOpenableNotional mapSymbolOpenableNotional(
  Object? payload, {
  required String symbol,
  required int leverage,
  required DateTime receivedAt,
}) {
  validatePositionSymbol(symbol);
  if (leverage <= 0 || payload is! Map<String, dynamic>) throw const FormatException();
  final raw = payload['remainingOpenableNotionalValue'];
  if (raw is! String ||
      raw.length > 160 ||
      raw != '-1' && !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(raw)) {
    throw const FormatException('Invalid symbol capacity');
  }
  return SymbolOpenableNotional(
    symbol: symbol,
    leverage: leverage,
    receivedAt: receivedAt,
    remaining: raw == '-1' ? null : Decimal.parse(raw),
  );
}

import 'package:decimal/decimal.dart';

import '../domain/futures_position_mode.dart';
import 'position_configuration_rows.dart';

FuturesPositionMode mapFuturesPositionMode(Object? payload) {
  if (payload is! Map<String, dynamic> || payload['dualSidePosition'] is! bool) {
    throw const FormatException('Missing position mode');
  }
  return payload['dualSidePosition'] == true
      ? FuturesPositionMode.hedge
      : FuturesPositionMode.oneWay;
}

/// The unfiltered account response is required. Zero rows remain subject to
/// validation; no position side or quantity is inferred from absent fields.
bool hasPositionModeBlocker(Object? payload, FuturesPositionMode mode) {
  if (payload is! List) throw const FormatException('Missing positions');
  final keys = <String>{};
  var nonzero = false;
  for (final row in payload) {
    if (row is! Map<String, dynamic> || row['symbol'] is! String) {
      throw const FormatException('Invalid position');
    }
    validatePositionSymbol(row['symbol'] as String);
    final side = row['positionSide'];
    if (!(mode == FuturesPositionMode.oneWay ? {'BOTH'} : {'LONG', 'SHORT'}).contains(side) ||
        !keys.add('${row['symbol']}:$side')) {
      throw const FormatException('Conflicting position mode');
    }
    final raw = row['positionAmt'];
    if (raw is! String && raw is! int) throw const FormatException('Missing quantity');
    final text = '$raw';
    if (text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
      throw const FormatException('Invalid quantity');
    }
    final quantity = Decimal.parse(text);
    if (side == 'LONG' && quantity < Decimal.zero || side == 'SHORT' && quantity > Decimal.zero) {
      throw const FormatException('Invalid direction');
    }
    nonzero |= quantity != Decimal.zero;
  }
  return nonzero;
}

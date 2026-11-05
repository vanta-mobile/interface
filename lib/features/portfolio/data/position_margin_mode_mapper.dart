import 'package:decimal/decimal.dart';

import '../domain/position_margin_mode.dart';
import 'position_configuration_rows.dart';

({PositionMarginMode mode, bool hasPosition}) mapMarginConfiguration(
  Object? payload,
  String symbol,
) {
  PositionMarginMode? mode;
  var hasPosition = false;
  for (final row in positionConfigurationRows(payload, symbol)) {
    final current = switch (row['marginType']) {
      'isolated' => PositionMarginMode.isolated,
      'cross' => PositionMarginMode.cross,
      _ => throw const FormatException('Invalid margin mode'),
    };
    final amount = row['positionAmt'];
    if (mode != null && mode != current ||
        amount is! String ||
        !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(amount)) {
      throw const FormatException('Invalid margin configuration');
    }
    final quantity = Decimal.parse(amount);
    if (row['positionSide'] == 'LONG' && quantity < Decimal.zero ||
        row['positionSide'] == 'SHORT' && quantity > Decimal.zero) {
      throw const FormatException('Invalid quantity direction');
    }
    mode = current;
    hasPosition |= quantity != Decimal.zero;
  }
  return (mode: mode!, hasPosition: hasPosition);
}

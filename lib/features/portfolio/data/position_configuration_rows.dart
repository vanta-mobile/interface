void validatePositionSymbol(String symbol) {
  if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol)) {
    throw const FormatException('Invalid symbol');
  }
}

/// Zero-quantity rows are configuration, and must not be filtered as closed
/// positions. Both hedge sides must agree on each symbol-scoped setting.
List<Map<String, dynamic>> positionConfigurationRows(Object? payload, String symbol) {
  if (payload is! List || payload.isEmpty) throw const FormatException('Missing configuration');
  final sides = <String>{}, rows = <Map<String, dynamic>>[];
  for (final row in payload) {
    if (row is! Map<String, dynamic> ||
        row['symbol'] != symbol ||
        !{'BOTH', 'LONG', 'SHORT'}.contains(row['positionSide']) ||
        !sides.add(row['positionSide'] as String)) {
      throw const FormatException('Invalid configuration');
    }
    rows.add(row);
  }
  if (sides.contains('BOTH') && sides.length != 1 || !sides.contains('BOTH') && sides.length != 2) {
    throw const FormatException('Incomplete position mode');
  }
  return rows;
}

import '../domain/position_adl.dart';

PositionAdlSnapshot mapPositionAdl(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
}) {
  if (payload is! List) throw const FormatException();
  final symbols = <String, PositionAdlQuantiles>{};
  for (final item in payload) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    final symbol = item['symbol'];
    final quantiles = item['adlQuantile'];
    if (symbol is! String ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol) ||
        symbols.containsKey(symbol) ||
        quantiles is! Map<String, dynamic>) {
      throw const FormatException();
    }
    final levels = <String, int>{};
    final hedge = quantiles.containsKey('HEDGE');
    for (final entry in quantiles.entries) {
      if (entry.key == 'HEDGE') {
        // Only marker presence matters; the integer is explicitly not a level.
        if (entry.value is! int) throw const FormatException();
      } else {
        final level = entry.value;
        if (!['BOTH', 'LONG', 'SHORT'].contains(entry.key) ||
            level is! int ||
            level < 0 ||
            level > 4) {
          throw const FormatException();
        }
        levels[entry.key] = level;
      }
    }
    if (hedge &&
        (levels.containsKey('BOTH') ||
            (levels.containsKey('LONG') &&
                levels.containsKey('SHORT') &&
                levels['LONG'] != levels['SHORT']))) {
      throw const FormatException();
    }
    symbols[symbol] = PositionAdlQuantiles(crossedHedge: hedge, levels: levels);
  }
  return PositionAdlSnapshot(address: address, receivedAt: receivedAt, symbols: symbols);
}

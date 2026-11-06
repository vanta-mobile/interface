import '../domain/position_margin_adjustment.dart';
import 'position_configuration_rows.dart';
import 'position_margin_mapper.dart';

/// The unscoped USER_DATA response is an array. Preserve only requested
/// symbols, but reject duplicate/missing keys rather than guessing a tier.
Map<String, List<MarginRiskTier>> mapMainOrderRiskTiers(Object? payload, Set<String> symbols) {
  if (payload is! List || symbols.isEmpty) throw const FormatException();
  final seen = <String>{}, result = <String, List<MarginRiskTier>>{};
  for (final row in payload) {
    if (row is! Map<String, dynamic> || row['symbol'] is! String) {
      throw const FormatException();
    }
    final symbol = row['symbol'] as String;
    validatePositionSymbol(symbol);
    if (!seen.add(symbol)) throw const FormatException();
    if (symbols.contains(symbol)) result[symbol] = mapMarginRiskTiers(row, symbol);
  }
  if (symbols.any((s) => !result.containsKey(s))) throw const FormatException();
  return Map.unmodifiable(result);
}

import 'package:decimal/decimal.dart';

import '../domain/futures_asset_mode.dart';
import 'position_configuration_rows.dart';

FuturesAssetMode mapFuturesAssetMode(Object? payload) {
  if (payload is! Map<String, dynamic> || payload['multiAssetsMargin'] is! bool) {
    throw const FormatException('Missing asset mode');
  }
  return payload['multiAssetsMargin'] == true ? FuturesAssetMode.multi : FuturesAssetMode.single;
}

/// An empty configuration alone is not an open isolated position. Retained
/// isolated collateral, including negative balances, still requires attention.
List<String> mapAssetModeIsolatedSymbols(Object? payload) {
  if (payload is! List) throw const FormatException('Missing positions');
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final row in payload) {
    if (row is! Map<String, dynamic> || row['symbol'] is! String) {
      throw const FormatException('Invalid position');
    }
    final symbol = row['symbol'] as String;
    validatePositionSymbol(symbol);
    grouped.putIfAbsent(symbol, () => []).add(row);
  }
  final isolated = <String>[];
  bool? hedge;
  for (final entry in grouped.entries) {
    final rows = positionConfigurationRows(entry.value, entry.key);
    final currentHedge = rows.first['positionSide'] != 'BOTH';
    if (hedge != null && hedge != currentHedge) throw const FormatException('Mixed position modes');
    hedge = currentHedge;
    String? margin;
    var needsCross = false;
    for (final row in rows) {
      final mode = row['marginType'];
      if (mode != 'cross' && mode != 'isolated' || margin != null && margin != mode) {
        throw const FormatException('Invalid margin mode');
      }
      margin = mode as String;
      final quantity = _decimal(row['positionAmt']);
      final wallet = _decimal(row['isolatedWallet']);
      if (row['positionSide'] == 'LONG' && quantity < Decimal.zero ||
          row['positionSide'] == 'SHORT' && quantity > Decimal.zero) {
        throw const FormatException('Invalid direction');
      }
      if (mode == 'isolated' && (quantity != Decimal.zero || wallet != Decimal.zero)) {
        needsCross = true;
      }
    }
    if (needsCross) isolated.add(entry.key);
  }
  return List.unmodifiable(isolated..sort());
}

Decimal _decimal(Object? value) {
  if (value is! String && value is! int) throw const FormatException('Missing amount');
  final text = '$value';
  if (text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException('Invalid amount');
  }
  return Decimal.parse(text);
}

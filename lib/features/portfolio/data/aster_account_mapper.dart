import 'package:decimal/decimal.dart';

import '../domain/aster_account.dart';
import 'account_update_time.dart';

/// Reject malformed money instead of manufacturing zero or silently dropping
/// a balance. A failed refresh leaves the prior snapshot visibly stale.
AsterAccount mapAsterAccount(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
  Map<String, AsterContractUnits> units = const {},
}) {
  final json = _object(payload);
  final assetClocks = <String, DateTime>{}, positionClocks = <String, DateTime>{};
  final assets = _list(json['assets']).map((item) {
    final row = _object(item);
    final name = _identifier(row['asset']);
    final updated = mapAccountUpdateTime(row['updateTime']);
    if (updated != null) assetClocks[name] = updated;
    return AsterAssetBalance(
      asset: name,
      walletBalance: _decimal(row['walletBalance']) ?? (throw const FormatException()),
      availableBalance: _decimal(row['availableBalance']),
      unrealizedProfit: _decimal(row['unrealizedProfit']),
      marginAvailable: _boolean(row['marginAvailable']),
      crossWalletBalance: _decimal(row['crossWalletBalance']),
      crossUnrealizedProfit: _decimal(row['crossUnPnl']),
    );
  }).toList();
  final positions = _list(json['positions']).map((item) {
    final row = _object(item);
    final side = row['positionSide'];
    if (!['BOTH', 'LONG', 'SHORT'].contains(side)) throw const FormatException();
    final leverage = row['leverage'];
    final parsedLeverage = leverage == null ? null : int.tryParse('$leverage');
    if (leverage != null && (parsedLeverage == null || parsedLeverage < 1)) {
      throw const FormatException();
    }
    final price = _decimal(row['entryPrice']);
    if (price != null && price < Decimal.zero) throw const FormatException();
    final symbol = _identifier(row['symbol']);
    final updated = mapAccountUpdateTime(row['updateTime']);
    if (updated != null) positionClocks['$symbol:$side'] = updated;
    final quantity = _decimal(row['positionAmt']) ?? (throw const FormatException());
    if ((side == 'LONG' && quantity < Decimal.zero) ||
        (side == 'SHORT' && quantity > Decimal.zero)) {
      throw const FormatException();
    }
    return AsterPosition(
      symbol: symbol,
      side: side! as String,
      quantity: quantity,
      entryPrice: price,
      unrealizedProfit: _decimal(row['unrealizedProfit']),
      initialMargin: _decimal(row['positionInitialMargin']),
      maintenanceMargin: _decimal(row['maintMargin']),
      leverage: parsedLeverage,
      isolated: _boolean(row['isolated']),
      units: units[symbol],
      isolatedWallet: _decimal(row['isolatedWallet']),
    );
  }).toList();
  if (assets.map((asset) => asset.asset).toSet().length != assets.length ||
      positions.map((p) => '${p.symbol}:${p.side}').toSet().length != positions.length) {
    throw const FormatException();
  }
  return AsterAccount(
    address: address,
    receivedAt: receivedAt,
    walletBalance: _decimal(json['totalWalletBalance']),
    marginBalance: _decimal(json['totalMarginBalance']),
    availableBalance: _decimal(json['availableBalance']),
    unrealizedProfit: _decimal(json['totalUnrealizedProfit']),
    initialMargin: _decimal(json['totalInitialMargin']),
    canTrade: _boolean(json['canTrade']),
    assets: assets,
    positions: positions.where(
      (position) =>
          position.quantity != Decimal.zero ||
          position.isolated == true && (position.isolatedWallet ?? Decimal.zero) < Decimal.zero,
    ),
    assetUpdatedAt: assetClocks,
    positionUpdatedAt: positionClocks,
    units: units,
  );
}

/// Metadata includes inactive symbols so a remaining position is not hidden
/// just because its contract is no longer listed in the market selector.
Map<String, AsterContractUnits> mapAsterContractUnits(Object? payload) {
  final result = <String, AsterContractUnits>{};
  for (final item in _list(_object(payload)['symbols'])) {
    final row = _object(item);
    final symbol = _identifier(row['symbol']);
    if (result.containsKey(symbol)) throw const FormatException();
    result[symbol] = AsterContractUnits(
      base: _identifier(row['baseAsset']),
      quote: _identifier(row['quoteAsset']),
      margin: _identifier(row['marginAsset']),
    );
  }
  return Map.unmodifiable(result);
}

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : throw const FormatException();
List<dynamic> _list(Object? value) =>
    value is List<dynamic> ? value : throw const FormatException();
String _identifier(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();
bool? _boolean(Object? value) =>
    value == null || value is bool ? value as bool? : throw const FormatException();
Decimal? _decimal(Object? value) {
  if (value == null) return null;
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

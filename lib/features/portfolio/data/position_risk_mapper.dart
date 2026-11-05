import 'package:decimal/decimal.dart';

import '../domain/aster_account.dart';
import '../domain/position_risk.dart';
import 'account_update_time.dart';

PositionRiskSnapshot mapPositionRisk(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
  Map<String, AsterContractUnits> units = const {},
}) {
  if (payload is! List) throw const FormatException();
  final positions = <PositionRisk>[];
  final keys = <String>{};
  final sidesBySymbol = <String, Set<String>>{};
  final clocks = <String, DateTime>{};
  for (final item in payload) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    final symbol = item['symbol'];
    final side = item['positionSide'];
    if (symbol is! String ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol) ||
        side is! String ||
        !['BOTH', 'LONG', 'SHORT'].contains(side) ||
        !keys.add('$symbol:$side')) {
      throw const FormatException();
    }
    final sides = sidesBySymbol.putIfAbsent(symbol, () => <String>{})..add(side);
    if (sides.contains('BOTH') && sides.length > 1) throw const FormatException();
    final quantity = _required(item['positionAmt']);
    if ((side == 'LONG' && quantity < Decimal.zero) ||
        (side == 'SHORT' && quantity > Decimal.zero)) {
      throw const FormatException();
    }
    final marginType = item['marginType'];
    if (marginType != 'isolated' && marginType != 'cross') throw const FormatException();
    final leverage = item['leverage'];
    if (leverage is! String && leverage is! int) throw const FormatException();
    final parsedLeverage = int.tryParse('$leverage');
    if (parsedLeverage == null || parsedLeverage < 1) throw const FormatException();
    final updated = mapAccountUpdateTime(item['updateTime']);
    if (updated != null) clocks['$symbol:$side'] = updated;
    final wallet = _required(item['isolatedWallet']);
    final position = PositionRisk(
      symbol: symbol,
      side: side,
      quantity: quantity,
      entryPrice: _nonnegative(_required(item['entryPrice']))!,
      markPrice: _nonnegative(_required(item['markPrice']))!,
      liquidationPrice: _nonnegative(_decimal(item['liquidationPrice'])),
      isolated: marginType == 'isolated',
      isolatedWallet: wallet,
      isolatedMargin: _decimal(item['isolatedMargin']),
      leverage: parsedLeverage,
      unrealizedProfit: _decimal(item['unRealizedProfit']),
      notional: _decimal(item['notional']),
      updatedAt: updated,
      units: units[symbol],
    );
    if (quantity != Decimal.zero || (position.isolated && wallet < Decimal.zero)) {
      positions.add(position);
    }
  }
  return PositionRiskSnapshot(
    address: address,
    receivedAt: receivedAt,
    positions: positions,
    positionUpdatedAt: clocks,
    units: units,
  );
}

Decimal _required(Object? value) => _decimal(value) ?? (throw const FormatException());
Decimal? _nonnegative(Decimal? value) {
  if (value != null && value < Decimal.zero) throw const FormatException();
  return value;
}

Decimal? _decimal(Object? value) {
  if (value == null) return null;
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

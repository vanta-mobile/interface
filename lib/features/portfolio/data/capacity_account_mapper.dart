import 'package:decimal/decimal.dart';

import '../domain/aster_account.dart';
import '../domain/main_order_capacity.dart';
import 'position_configuration_rows.dart';
import 'position_margin_mapper.dart';

CapacityAccount mapCapacityAccount(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
  required Map<String, AsterContractUnits> units,
}) {
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
      payload is! Map<String, dynamic> ||
      payload['canTrade'] is! bool ||
      payload['assets'] is! List ||
      payload['positions'] is! List) {
    throw const FormatException('Invalid capacity account');
  }
  final assets = <CapacityAsset>[], positions = <CapacityPosition>[];
  final assetKeys = <String>{}, positionKeys = <String>{};
  for (final raw in payload['assets'] as List) {
    if (raw is! Map<String, dynamic> ||
        raw['asset'] is! String ||
        raw['marginAvailable'] is! bool) {
      throw const FormatException();
    }
    final asset = raw['asset'] as String;
    validatePositionSymbol(asset);
    if (!assetKeys.add(asset)) throw const FormatException();
    assets.add(
      CapacityAsset(
        asset: asset,
        available: marginDecimal(raw['availableBalance']),
        crossWallet: marginDecimal(raw['crossWalletBalance']),
        crossPnl: marginDecimal(raw['crossUnPnl']),
        initialMargin: _nonnegative(raw['initialMargin']),
        marginAvailable: raw['marginAvailable'] as bool,
      ),
    );
  }
  for (final raw in payload['positions'] as List) {
    if (raw is! Map<String, dynamic> ||
        raw['symbol'] is! String ||
        !{'BOTH', 'LONG', 'SHORT'}.contains(raw['positionSide']) ||
        raw['isolated'] is! bool ||
        raw['leverage'] is! String ||
        !RegExp(r'^[1-9]\d{0,3}$').hasMatch(raw['leverage'] as String)) {
      throw const FormatException();
    }
    final symbol = raw['symbol'] as String, side = raw['positionSide'] as String;
    validatePositionSymbol(symbol);
    final unit = units[symbol];
    if (!positionKeys.add('$symbol:$side') ||
        unit == null ||
        !assetKeys.contains(unit.margin) ||
        unit.margin != unit.quote) {
      throw const FormatException();
    }
    final quantity = marginDecimal(raw['positionAmt']), notional = marginDecimal(raw['notional']);
    if (side == 'LONG' && quantity < Decimal.zero ||
        side == 'SHORT' && quantity > Decimal.zero ||
        (quantity == Decimal.zero) != (notional == Decimal.zero) ||
        quantity != Decimal.zero && (quantity < Decimal.zero) != (notional < Decimal.zero)) {
      throw const FormatException();
    }
    final maxNotional = _nonnegative(raw['maxNotional']);
    if (maxNotional == Decimal.zero) throw const FormatException();
    positions.add(
      CapacityPosition(
        symbol: symbol,
        side: side,
        quantity: quantity,
        entryPrice: _nonnegative(raw['entryPrice']),
        notional: notional,
        leverage: int.parse(raw['leverage'] as String),
        isolated: raw['isolated'] as bool,
        orderMargin: _nonnegative(raw['openOrderInitialMargin']),
        maintenance: _nonnegative(raw['maintMargin']),
        maxNotional: maxNotional,
        units: unit,
        isolatedWallet: marginDecimal(raw['isolatedWallet']),
      ),
    );
  }
  return CapacityAccount(
    address: address,
    receivedAt: receivedAt,
    canTrade: payload['canTrade'] as bool,
    assets: assets,
    positions: positions,
  );
}

Decimal _nonnegative(Object? raw) {
  final value = marginDecimal(raw);
  if (value < Decimal.zero) throw const FormatException();
  return value;
}

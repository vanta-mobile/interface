import 'package:decimal/decimal.dart';

import '../domain/account_update.dart';

AccountUpdate mapAccountUpdate(Map<String, dynamic> payload) {
  if (payload['e'] != 'ACCOUNT_UPDATE') throw const FormatException();
  final data = _object(payload['a']);
  // Reason strings may be extended by the exchange. Validate but never use
  // them to infer cash flow, deposit finality or execution.
  final reason = _identifier(data['m']);
  final balances = <AccountBalanceUpdate>[];
  final positions = <AccountPositionUpdate>[];
  final assets = <String>{}, keys = <String>{};
  for (final raw in _optionalList(data['B'])) {
    final row = _object(raw);
    final asset = _identifier(row['a']);
    if (!assets.add(asset)) throw const FormatException();
    if (row['bc'] != null) _decimal(row['bc']);
    balances.add(
      AccountBalanceUpdate(
        asset: asset,
        walletBalance: _decimal(row['wb']),
        crossWalletBalance: _decimal(row['cw']),
        change: row['bc'] == null ? null : _decimal(row['bc']),
      ),
    );
  }
  for (final raw in _optionalList(data['P'])) {
    final row = _object(raw);
    final symbol = _identifier(row['s']);
    final side = row['ps'];
    final marginType = row['mt'];
    final quantity = _decimal(row['pa']);
    final entry = _decimal(row['ep']);
    if (side is! String ||
        !{'BOTH', 'LONG', 'SHORT'}.contains(side) ||
        !keys.add('$symbol:$side') ||
        !{'cross', 'isolated'}.contains(marginType) ||
        entry < Decimal.zero ||
        side == 'LONG' && quantity < Decimal.zero ||
        side == 'SHORT' && quantity > Decimal.zero) {
      throw const FormatException();
    }
    // cr is accumulated realized PnL before fees, never a wallet balance.
    if (row['cr'] != null) _decimal(row['cr']);
    positions.add(
      AccountPositionUpdate(
        symbol: symbol,
        side: side,
        quantity: quantity,
        entryPrice: entry,
        unrealizedProfit: _decimal(row['up']),
        isolated: marginType == 'isolated',
        isolatedWallet: _decimal(row['iw']),
      ),
    );
  }
  if (balances.isEmpty && positions.isEmpty) throw const FormatException();
  return AccountUpdate(
    eventTime: _time(payload['E']),
    transactionTime: _time(payload['T']),
    reason: reason,
    balances: balances,
    positions: positions,
  );
}

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : throw const FormatException();
Iterable<dynamic> _optionalList(Object? value) => value == null
    ? const []
    : value is List<dynamic>
    ? value
    : throw const FormatException();
String _identifier(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();
Decimal _decimal(Object? value) {
  if (value is! String || value.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

DateTime _time(Object? value) => value is int && value > 0 && value <= 253402300799999
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : throw const FormatException();

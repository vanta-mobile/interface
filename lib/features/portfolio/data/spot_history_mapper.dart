import 'package:decimal/decimal.dart';

import '../domain/spot_history.dart';

SpotHistoryPage mapSpotHistory(
  Object? payload, {
  required String address,
  required SpotHistoryQuery query,
  required DateTime receivedAt,
  Map<String, SpotSymbolUnits> units = const {},
}) {
  if (payload is! List<dynamic> || payload.length > SpotHistoryPage.limit) {
    throw const FormatException();
  }
  final records = <String, SpotHistoryRecord>{};
  for (final item in payload) {
    final row = _object(item);
    final time = _time(row['time']);
    if (time.millisecondsSinceEpoch < query.window.start ||
        time.millisecondsSinceEpoch > query.window.end) {
      throw const FormatException();
    }
    final record = switch (query.kind) {
      SpotHistoryKind.orders => _order(row, time, units),
      SpotHistoryKind.trades => _trade(row, time, units),
      SpotHistoryKind.transactions => _transaction(row, time),
    };
    final scope = record is SpotTransactionRecord ? record.asset : record.symbol;
    if (query.scope.isNotEmpty && scope != query.scope) throw const FormatException();
    final previous = records[record.key];
    if (previous != null && historyRecordsConflict(previous, record)) {
      throw const FormatException();
    }
    if (previous == null || !record.versionTime.isBefore(previous.versionTime)) {
      records[record.key] = record;
    }
  }
  return SpotHistoryPage(
    address: address,
    query: query,
    receivedAt: receivedAt,
    records: sortSpotHistory(records.values),
    rawCount: payload.length,
  );
}

SpotOrderRecord _order(
  Map<String, dynamic> row,
  DateTime time,
  Map<String, SpotSymbolUnits> units,
) {
  final symbol = _identifier(row['symbol']);
  final quantity = _amount(row['origQty']);
  final executed = _amount(row['executedQty']);
  final updated = row['updateTime'] == null ? time : _time(row['updateTime']);
  if (quantity <= Decimal.zero || executed > quantity || updated.isBefore(time)) {
    throw const FormatException();
  }
  return SpotOrderRecord(
    symbol: symbol,
    time: time,
    orderId: _id(row['orderId']),
    side: _side(row['side']),
    type: _code(row['type']),
    status: _code(row['status']),
    updatedAt: updated,
    quantity: quantity,
    executed: executed,
    price: _amount(row['price']),
    quoteFilled: _amount(row['cumQuote']),
    averagePrice: row['avgPrice'] == null ? null : _amount(row['avgPrice']),
    stopPrice: row['stopPrice'] == null ? null : _amount(row['stopPrice']),
    timeInForce: row['timeInForce'] == null ? null : _code(row['timeInForce']),
    units: units[symbol],
  );
}

SpotTradeRecord _trade(
  Map<String, dynamic> row,
  DateTime time,
  Map<String, SpotSymbolUnits> units,
) {
  final symbol = _identifier(row['symbol']);
  final side = _side(row['side']);
  if (row['maker'] is! bool ||
      (row['buyer'] != null && (row['buyer'] is! bool || row['buyer'] != (side == 'BUY')))) {
    throw const FormatException();
  }
  final price = _amount(row['price']);
  final quantity = _amount(row['qty']);
  if (price <= Decimal.zero || quantity <= Decimal.zero) throw const FormatException();
  return SpotTradeRecord(
    symbol: symbol,
    time: time,
    tradeId: _id(row['id']),
    orderId: _id(row['orderId']),
    side: side,
    price: price,
    quantity: quantity,
    quoteQuantity: _amount(row['quoteQty']),
    commission: _amount(row['commission'], signed: true),
    commissionAsset: _identifier(row['commissionAsset']),
    maker: row['maker'] as bool,
    units: units[symbol],
  );
}

SpotTransactionRecord _transaction(Map<String, dynamic> row, DateTime time) =>
    SpotTransactionRecord(
      symbol: row['symbol'] == null || row['symbol'] == '' ? '' : _identifier(row['symbol']),
      time: time,
      transactionId: _id(row['tranId']),
      asset: _identifier(row['asset']),
      type: _code(row['type']),
      delta: _amount(row['balanceDelta'], signed: true),
      tradeId: row['tradeId'] == null || row['tradeId'] == '' ? null : _id(row['tradeId']),
    );

Map<String, SpotSymbolUnits> mapSpotSymbolUnits(Object? payload) {
  final symbols = _object(payload)['symbols'];
  if (symbols is! List<dynamic>) throw const FormatException();
  final result = <String, SpotSymbolUnits>{};
  for (final item in symbols) {
    final row = _object(item);
    final symbol = _identifier(row['symbol']);
    if (result.containsKey(symbol)) throw const FormatException();
    result[symbol] = SpotSymbolUnits(
      base: _identifier(row['baseAsset']),
      quote: _identifier(row['quoteAsset']),
    );
  }
  return Map.unmodifiable(result);
}

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : throw const FormatException();
String _identifier(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();
String _code(Object? value) => value is String && RegExp(r'^[A-Z][A-Z0-9_]{0,59}$').hasMatch(value)
    ? value
    : throw const FormatException();
String _side(Object? value) =>
    value == 'BUY' || value == 'SELL' ? value! as String : throw const FormatException();
String _id(Object? value) {
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (!RegExp(r'^(0|[1-9]\d{0,30})$').hasMatch(text)) throw const FormatException();
  return text;
}

DateTime _time(Object? value) {
  if (value is! int || value < 0) throw const FormatException();
  try {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  } catch (_) {
    throw const FormatException();
  }
}

Decimal _amount(Object? value, {bool signed = false}) {
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (text.length > 160 ||
      !(signed ? RegExp(r'^-?\d+(?:\.\d+)?$') : RegExp(r'^\d+(?:\.\d+)?$')).hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

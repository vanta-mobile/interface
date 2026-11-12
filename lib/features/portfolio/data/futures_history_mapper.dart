import 'package:decimal/decimal.dart';

import '../domain/aster_account.dart';
import '../domain/futures_history.dart';
import '../domain/futures_history_merge.dart';

FuturesHistoryPage mapFuturesHistory(
  Object? payload, {
  required String address,
  required FuturesHistoryQuery query,
  required DateTime receivedAt,
  Map<String, AsterContractUnits> units = const {},
}) {
  if (!query.valid ||
      !query.window.fitsRequest ||
      payload is! List ||
      payload.length > FuturesHistoryPage.limit) {
    throw const FormatException('Invalid history page');
  }
  final records = <FuturesHistoryRecord>[];
  for (final item in payload) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    final time = _time(item['time']);
    final record = switch (query.kind) {
      FuturesHistoryKind.orders => _order(item, time, units),
      FuturesHistoryKind.trades => _trade(item, time, units),
      FuturesHistoryKind.income => _income(item, time),
    };
    if (!futuresHistoryMatches(record, query)) {
      throw const FormatException('History scope mismatch');
    }
    records.add(record);
  }
  return FuturesHistoryPage(
    address: address,
    query: query,
    receivedAt: receivedAt,
    records: mergeFuturesHistory(const [], records),
    rawCount: payload.length,
  );
}

/// An order-filtered request has no time window. Validate every row against
/// its exact symbol/order and optional continuation ID instead.
List<FuturesTradeRecord> mapFuturesOrderFills(
  Object? payload, {
  required String symbol,
  required String orderId,
  String? fromId,
}) {
  if (payload is! List || payload.length > FuturesHistoryPage.limit) throw const FormatException();
  final rows = <FuturesTradeRecord>[];
  for (final item in payload) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    final r = _trade(item, _time(item['time']), const {});
    if (r.symbol != symbol ||
        r.orderId != orderId ||
        fromId != null && BigInt.parse(r.tradeId) < BigInt.parse(fromId)) {
      throw const FormatException();
    }
    rows.add(r);
  }
  return mergeFuturesHistory(const [], rows).cast<FuturesTradeRecord>();
}

FuturesOrderRecord _order(
  Map<String, dynamic> row,
  DateTime time,
  Map<String, AsterContractUnits> units,
) {
  final symbol = _identifier(row['symbol']);
  final quantity = _amount(row['origQty']), executed = _amount(row['executedQty']);
  final close = _bool(row['closePosition']);
  final updated = _time(row['updateTime']);
  final status = _code(row['status']);
  final quote = _optionalAmount(row['cumQuote']), average = _optionalAmount(row['avgPrice']);
  // Aster can report updateTime slightly before time for filled orders.
  // These are independent exchange timestamps; preserve both as reported.
  if (updated.millisecondsSinceEpoch <= 0 ||
      quantity == Decimal.zero && close != true ||
      close != true && executed > quantity ||
      status == 'NEW' && executed != Decimal.zero ||
      status == 'PARTIALLY_FILLED' &&
          (executed <= Decimal.zero || close != true && executed >= quantity) ||
      status == 'FILLED' && (executed <= Decimal.zero || close != true && executed != quantity) ||
      executed == Decimal.zero &&
          (quote != null && quote != Decimal.zero || average != null && average != Decimal.zero)) {
    throw const FormatException('Inconsistent order history');
  }
  return FuturesOrderRecord(
    symbol: symbol,
    time: time,
    orderId: _id(row['orderId']),
    clientOrderId: row['clientOrderId'] == null ? null : _clientId(row['clientOrderId']),
    side: _side(row['side']),
    positionSide: _position(row['positionSide']),
    type: _code(row['type']),
    originalType: row['origType'] == null ? null : _code(row['origType']),
    status: status,
    updatedAt: updated,
    quantity: quantity,
    executed: executed,
    price: _amount(row['price']),
    quoteFilled: quote,
    averagePrice: average,
    stopPrice: _optionalAmount(row['stopPrice']),
    timeInForce: row['timeInForce'] == null ? null : _code(row['timeInForce']),
    workingType: row['workingType'] == null ? null : _code(row['workingType']),
    activationPrice: _optionalAmount(row['activatePrice']),
    callbackRate: _optionalAmount(row['priceRate']),
    reduceOnly: _bool(row['reduceOnly']),
    closePosition: close,
    priceProtect: _bool(row['priceProtect']),
    units: units[symbol],
  );
}

FuturesTradeRecord _trade(
  Map<String, dynamic> row,
  DateTime time,
  Map<String, AsterContractUnits> units,
) {
  final symbol = _identifier(row['symbol']), side = _side(row['side']);
  final buyer = _bool(row['buyer']);
  final maker = _bool(row['maker']);
  final price = _amount(row['price']), quantity = _amount(row['qty']);
  if (maker == null ||
      buyer != null && buyer != (side == 'BUY') ||
      price <= Decimal.zero ||
      quantity <= Decimal.zero) {
    throw const FormatException('Invalid trade');
  }
  return FuturesTradeRecord(
    symbol: symbol,
    time: time,
    tradeId: _id(row['id']),
    orderId: _id(row['orderId']),
    side: side,
    positionSide: _position(row['positionSide']),
    price: price,
    quantity: quantity,
    quoteQuantity: _amount(row['quoteQty']),
    commission: _amount(row['commission'], signed: true),
    commissionAsset: _identifier(row['commissionAsset']),
    realizedPnl: _amount(row['realizedPnl'], signed: true),
    maker: maker,
    units: units[symbol],
  );
}

FuturesIncomeRecord _income(Map<String, dynamic> row, DateTime time) => FuturesIncomeRecord(
  symbol: row['symbol'] == '' ? '' : _identifier(row['symbol']),
  time: time,
  transactionId: _id(row['tranId']),
  asset: _identifier(row['asset']),
  type: _code(row['incomeType']),
  income: _amount(row['income'], signed: true),
  tradeId: row['tradeId'] == null || row['tradeId'] == '' ? null : _id(row['tradeId']),
);
String _identifier(Object? v) =>
    v is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(v)
    ? v
    : throw const FormatException();
String _code(Object? v) => v is String && RegExp(r'^[A-Z][A-Z0-9_]{0,59}$').hasMatch(v)
    ? v
    : throw const FormatException();
String _clientId(Object? v) => v is String && RegExp(r'^[.A-Z:/a-z0-9_-]{1,36}$').hasMatch(v)
    ? v
    : throw const FormatException();
String _side(Object? v) => v == 'BUY' || v == 'SELL' ? v! as String : throw const FormatException();
String _position(Object? v) =>
    {'BOTH', 'LONG', 'SHORT'}.contains(v) ? v! as String : throw const FormatException();
bool? _bool(Object? v) => v == null || v is bool ? v as bool? : throw const FormatException();
String _id(Object? v) {
  if (v is! int && v is! String) throw const FormatException();
  final value = '$v';
  return RegExp(r'^(0|[1-9]\d{0,30})$').hasMatch(value) ? value : throw const FormatException();
}

DateTime _time(Object? v) {
  if (v is! int || v < 0 || v > 8640000000000000) throw const FormatException();
  return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
}

Decimal? _optionalAmount(Object? v) => v == null ? null : _amount(v);
Decimal _amount(Object? v, {bool signed = false}) {
  if (v is! String && v is! int) throw const FormatException();
  final value = '$v';
  if (value.length > 160 ||
      !(signed ? RegExp(r'^-?\d+(?:\.\d+)?$') : RegExp(r'^\d+(?:\.\d+)?$')).hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

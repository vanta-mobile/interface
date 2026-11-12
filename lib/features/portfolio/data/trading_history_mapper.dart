import 'package:decimal/decimal.dart';

import '../domain/trading_history.dart';

typedef HistoryJson = Map<String, Object?>;

List<TradingHistoryRecord> mapTradingHistory(
  Object? value,
  TradingHistoryTab tab, {
  bool transfers = false,
  String pageKey = 'first',
}) {
  if (value is! List || value.length > 200) throw const FormatException();
  return value.indexed.map((entry) {
    final (index, item) = entry;
    if (item is! HistoryJson) throw const FormatException();
    final symbol = _optionalText(item['symbol']) ?? '';
    return switch (tab) {
      TradingHistoryTab.orders => HistoryOrder(
        symbol: _text(symbol),
        time: _time(item['order_time']),
        id: _id(item['order_id']),
        side: _side(item['side']),
        positionSide: _positionSide(item['position_side']),
        type: _text(item['orig_type'] ?? item['type']),
        status: _text(item['status']),
        executed: _positive(item['executed_qty']),
        quantity: _optionalPositive(item['orig_qty']),
        price: _optionalPositive(item['price']),
        averagePrice: _optionalPositive(item['avg_price']),
        reduceOnly: _optionalBool(item['reduce_only']),
        updatedAt: _optionalTime(item['update_time']),
      ),
      TradingHistoryTab.trades => HistoryFill(
        symbol: _text(symbol),
        time: _time(item['trade_time']),
        id: _id(item['trade_id']),
        orderId: item['order_id'] == null ? null : _id(item['order_id']),
        side: _side(item['side']),
        positionSide: _positionSide(item['position_side']),
        price: _positive(item['price'], nonzero: true),
        quantity: _positive(item['qty'], nonzero: true),
        fee: _decimal(item['fee']),
        feeAsset: _optionalText(item['fee_asset']),
        notional: _optionalPositive(item['notional']),
        realizedPnl: _optionalDecimal(item['realized_profit']),
      ),
      TradingHistoryTab.positions => _position(item, _text(symbol)),
      TradingHistoryTab.transactions => HistoryTransaction(
        symbol: symbol,
        time: _time(item['occurred_at']),
        id: transfers ? 'transfer:${_id(item['id'])}' : 'income:$pageKey:$index',
        type: _transactionType(_text(item['kind'])),
        asset: _text(item['asset']),
        amount: _decimal(item['amount']),
      ),
    };
  }).toList();
}

HistoryPosition _position(HistoryJson row, String symbol) {
  final status = _text(row['status']), side = _text(row['side']).toUpperCase();
  if (!{'open', 'closed'}.contains(status) || !{'LONG', 'SHORT'}.contains(side)) {
    throw const FormatException();
  }
  final opened = _time(row['opened_at']), closed = _optionalTime(row['closed_at']);
  if (closed != null && closed.isBefore(opened) || status == 'closed' && closed == null) {
    throw const FormatException();
  }
  return HistoryPosition(
    symbol: symbol,
    time: opened,
    id: _id(row['id']),
    side: side,
    status: status,
    entryPrice: _positive(row['entry_price']),
    exitPrice: _optionalPositive(row['exit_price']),
    maxQuantity: _positive(row['max_qty']),
    realizedPnl: _decimal(row['realized_pnl']),
    fees: _decimal(row['fees']),
    closedAt: closed,
    inferred: _bool(row['inferred']),
    liquidated: _bool(row['liquidated']),
  );
}

String _transactionType(String kind) => switch (kind) {
  'funding' => 'FUNDING_FEE',
  'deposit' => 'DEPOSIT',
  'withdraw' => 'WITHDRAW',
  'internal_transfer' => 'INTERNAL_TRANSFER',
  _ => kind,
};
String _text(Object? value) => value is String && value.isNotEmpty && value.length <= 200
    ? value
    : throw const FormatException();
String? _optionalText(Object? value) => value == null ? null : _text(value);
String _id(Object? value) => value is int && value >= 0 ? '$value' : throw const FormatException();
String _side(Object? value) =>
    {'BUY', 'SELL'}.contains(value) ? value as String : throw const FormatException();
String? _positionSide(Object? value) => value == null
    ? null
    : {'BOTH', 'LONG', 'SHORT'}.contains(value)
    ? value as String
    : throw const FormatException();
bool _bool(Object? value) => value is bool ? value : throw const FormatException();
bool? _optionalBool(Object? value) => value == null ? null : _bool(value);
Decimal _decimal(Object? value) {
  if (value is! String || value.length > 80 || !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

Decimal _positive(Object? value, {bool nonzero = false}) {
  final decimal = _decimal(value);
  if (decimal < Decimal.zero || nonzero && decimal == Decimal.zero) throw const FormatException();
  return decimal;
}

Decimal? _optionalDecimal(Object? value) => value == null ? null : _decimal(value);
Decimal? _optionalPositive(Object? value) => value == null ? null : _positive(value);
DateTime _time(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException();
  }
  return DateTime.parse(value).toUtc();
}

DateTime? _optionalTime(Object? value) => value == null ? null : _time(value);

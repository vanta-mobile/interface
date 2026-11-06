import 'package:decimal/decimal.dart';

import '../domain/order_reference_prices.dart';

OrderBookQuote mapOrderBookQuote(
  Object? payload, {
  required String symbol,
  required DateTime receivedAt,
  bool stream = false,
}) {
  final row = _row(payload, symbol: symbol, stream: stream, event: 'bookTicker');
  final bid = _price(row[stream ? 'b' : 'bidPrice']);
  final ask = _price(row[stream ? 'a' : 'askPrice']);
  // A zero-size side is not an executable quote, even if its last price remains.
  _price(row[stream ? 'B' : 'bidQty']);
  _price(row[stream ? 'A' : 'askQty']);
  if (bid > ask) throw const FormatException();
  return OrderBookQuote(
    symbol: symbol,
    bid: bid,
    ask: ask,
    eventTime: _time(row[stream ? 'T' : 'time']),
    receivedAt: receivedAt,
    updateId: stream ? _id(row['u']) : null,
  );
}

OrderTradeQuote mapOrderTradeQuote(
  Object? payload, {
  required String symbol,
  required DateTime receivedAt,
  bool stream = false,
}) {
  final Map<String, dynamic> row;
  if (stream) {
    row = _row(payload, symbol: symbol, stream: true, event: 'aggTrade');
    final first = _id(row['f']), last = _id(row['l']);
    if (first > last) throw const FormatException();
    _id(row['a']);
  } else {
    if (payload is! List || payload.length != 1 || payload.single is! Map<String, dynamic>) {
      throw const FormatException();
    }
    row = payload.single as Map<String, dynamic>;
  }
  _price(row[stream ? 'q' : 'qty']);
  return OrderTradeQuote(
    symbol: symbol,
    price: _price(row[stream ? 'p' : 'price']),
    tradeId: _id(row[stream ? 'l' : 'id']),
    eventTime: _time(row[stream ? 'T' : 'time']),
    receivedAt: receivedAt,
  );
}

Map<String, dynamic> _row(
  Object? payload, {
  required String symbol,
  required bool stream,
  required String event,
}) {
  if (payload is! Map<String, dynamic> ||
      payload[stream ? 's' : 'symbol'] != symbol ||
      stream && payload['e'] != event) {
    throw const FormatException();
  }
  if (stream) _time(payload['E']);
  return payload;
}

Decimal _price(Object? value) {
  if (value is! String || value.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException();
  }
  final price = Decimal.parse(value);
  if (price <= Decimal.zero) throw const FormatException();
  return price;
}

int _id(Object? value) {
  if (value is! int || value < 0) throw const FormatException();
  return value;
}

DateTime _time(Object? value) {
  if (value is! int || value <= 0 || value > 253402300799999) throw const FormatException();
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

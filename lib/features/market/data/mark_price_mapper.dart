import 'package:decimal/decimal.dart';

import '../domain/mark_prices.dart';

MarkPriceQuote mapMarkPrice(Object? payload, {required DateTime receivedAt, bool stream = false}) {
  if (payload is! Map<String, dynamic>) throw const FormatException();
  if (stream && payload['e'] != 'markPriceUpdate') throw const FormatException();
  final symbol = payload[stream ? 's' : 'symbol'];
  final rawPrice = payload[stream ? 'p' : 'markPrice'];
  final time = payload[stream ? 'E' : 'time'];
  if (symbol is! String ||
      !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol) ||
      rawPrice is! String ||
      rawPrice.length > 160 ||
      !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(rawPrice) ||
      time is! int ||
      time <= 0 ||
      time > 8640000000000000) {
    throw const FormatException();
  }
  final price = Decimal.parse(rawPrice);
  if (price <= Decimal.zero) throw const FormatException();
  return MarkPriceQuote(
    symbol: symbol,
    price: price,
    eventTime: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
    receivedAt: receivedAt,
  );
}

import 'package:decimal/decimal.dart';

import '../domain/account_notification.dart';

SpotOrderNotification mapSpotNotification(Map<String, dynamic> raw) {
  if (raw['e'] != 'executionReport') throw const FormatException();
  final type = _choice(raw['o'], _types);
  final execution = _choice(raw['x'], {'NEW', 'CANCELED', 'REJECTED', 'TRADE', 'EXPIRED'});
  final status = _choice(raw['X'], {
    'NEW',
    'PARTIALLY_FILLED',
    'FILLED',
    'CANCELED',
    'REJECTED',
    'EXPIRED',
  });
  final quantity = _decimal(raw['q']), filled = _decimal(raw['z']), last = _decimal(raw['l']);
  final quoteQuantity = raw['Q'] == null ? null : _decimal(raw['Q']);
  final price = _decimal(raw['p']), average = _decimal(raw['ap']), lastPrice = _decimal(raw['L']);
  final lastQuote = _decimal(raw['Y']), cumulativeQuote = _decimal(raw['Z']);
  final quoteOnly = type == 'MARKET' && quoteQuantity != null && quoteQuantity > Decimal.zero;
  if (quantity == Decimal.zero && !quoteOnly ||
      quantity > Decimal.zero && filled > quantity ||
      last > filled ||
      lastQuote > cumulativeQuote ||
      status == 'NEW' && filled != Decimal.zero ||
      status == 'PARTIALLY_FILLED' &&
          (filled == Decimal.zero || quantity > Decimal.zero && filled >= quantity) ||
      status == 'FILLED' &&
          (filled == Decimal.zero || quantity > Decimal.zero && filled != quantity) ||
      execution == 'TRADE' &&
          (last == Decimal.zero || lastPrice == Decimal.zero || average == Decimal.zero)) {
    throw const FormatException();
  }
  final fee = raw['n'] == null ? null : _decimal(raw['n'], signed: true);
  final asset = raw['N'] == null ? null : _symbol(raw['N']);
  if ((fee == null) != (asset == null)) throw const FormatException();
  return SpotOrderNotification(
    eventTime: _time(raw['E']),
    transactionTime: _time(raw['T']),
    symbol: _symbol(raw['s']),
    orderId: _id(raw['i']),
    clientOrderId: _client(raw['c']),
    side: _choice(raw['S'], {'BUY', 'SELL'}),
    orderType: type,
    originalType: raw['ot'] == null ? null : _choice(raw['ot'], _types),
    executionType: execution,
    status: status,
    quantity: quantity,
    price: price,
    averagePrice: average,
    lastQuantity: last,
    filledQuantity: filled,
    lastPrice: lastPrice,
    tradeId: _id(raw['t'], allowNegativeOne: execution != 'TRADE'),
    fee: fee,
    feeAsset: asset,
    lastQuoteAmount: lastQuote,
    cumulativeQuoteAmount: cumulativeQuote,
    creationMilliseconds: raw['O'] == null ? null : _milliseconds(raw['O'], allowZero: true),
    stopPrice: raw['P'] == null ? null : _decimal(raw['P']),
    quoteOrderQuantity: quoteQuantity,
  );
}

const _types = {'LIMIT', 'MARKET', 'STOP', 'TAKE_PROFIT', 'STOP_MARKET', 'TAKE_PROFIT_MARKET'};
String _choice(Object? value, Set<String> allowed) =>
    value is String && allowed.contains(value) ? value : throw const FormatException();
String _symbol(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();
String _client(Object? value) =>
    value is String && RegExp(r'^[a-zA-Z0-9_.:/-]{1,128}$').hasMatch(value)
    ? value
    : throw const FormatException();
String _id(Object? value, {bool allowNegativeOne = false}) {
  if (value is! int && value is! String) throw const FormatException();
  final text = '$value';
  if (allowNegativeOne && text == '-1' || RegExp(r'^(0|[1-9]\d{0,30})$').hasMatch(text)) {
    return text;
  }
  throw const FormatException();
}

Decimal _decimal(Object? value, {bool signed = false}) {
  if (value is! String ||
      value.length > 160 ||
      !(signed ? RegExp(r'^-?\d+(?:\.\d+)?$') : RegExp(r'^\d+(?:\.\d+)?$')).hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

int _milliseconds(Object? value, {bool allowZero = false}) {
  if (value is! int || value < (allowZero ? 0 : 1) || value > 253402300799999) {
    throw const FormatException();
  }
  return value;
}

DateTime _time(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(_milliseconds(value), isUtc: true);

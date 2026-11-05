import 'package:decimal/decimal.dart';

import '../domain/open_order_update.dart';

OpenOrderUpdate mapOpenOrderUpdate(Map<String, dynamic> payload) {
  if (payload['e'] != 'ORDER_TRADE_UPDATE') throw const FormatException();
  final raw = payload['o'];
  if (raw is! Map<String, dynamic>) throw const FormatException();
  final symbol = raw['s'];
  final id = raw['i'];
  if (symbol is! String ||
      !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol) ||
      !(id is int && id > 0 || id is String && RegExp(r'^[1-9]\d{0,30}$').hasMatch(id))) {
    throw const FormatException();
  }
  final status = _choice(raw['X'], {
    'NEW',
    'PARTIALLY_FILLED',
    'FILLED',
    'CANCELED',
    'EXPIRED',
    'REJECTED',
  });
  _choice(raw['x'], {'NEW', 'CANCELED', 'CALCULATED', 'EXPIRED', 'TRADE', 'AMENDMENT', 'REJECTED'});
  final type = _choice(raw['o'], {
    'LIMIT',
    'MARKET',
    'STOP',
    'STOP_MARKET',
    'TAKE_PROFIT',
    'TAKE_PROFIT_MARKET',
    'TRAILING_STOP_MARKET',
    'LIQUIDATION',
  });
  final quantity = _decimal(raw['q']);
  final filled = _decimal(raw['z']);
  final closeAll = _bool(raw['cp']);
  if (quantity != Decimal.zero && filled > quantity ||
      quantity == Decimal.zero && closeAll != true ||
      status == 'NEW' && filled != Decimal.zero ||
      status == 'PARTIALLY_FILLED' &&
          (filled == Decimal.zero || quantity != Decimal.zero && filled >= quantity) ||
      status == 'FILLED' && quantity != Decimal.zero && filled != quantity) {
    throw const FormatException();
  }
  final eventTime = _time(payload['E']);
  final transactionTime = _time(raw['T']);
  _time(payload['T']);
  return OpenOrderUpdate(
    symbol: symbol,
    orderId: '$id',
    status: status,
    eventTime: eventTime,
    transactionTime: transactionTime,
    side: _choice(raw['S'], {'BUY', 'SELL'}),
    positionSide: _choice(raw['ps'], {'BOTH', 'LONG', 'SHORT'}),
    type: type,
    originalType: raw['ot'] == null
        ? null
        : _choice(raw['ot'], {
            'LIMIT',
            'MARKET',
            'STOP',
            'STOP_MARKET',
            'TAKE_PROFIT',
            'TAKE_PROFIT_MARKET',
            'TRAILING_STOP_MARKET',
            'LIQUIDATION',
          }),
    timeInForce: _choice(raw['f'], {'GTC', 'IOC', 'FOK', 'GTX', 'HIDDEN'}),
    origQty: quantity,
    executedQty: filled,
    price: _decimal(raw['p']),
    reduceOnly: _bool(raw['R']) ?? (throw const FormatException()),
    closePosition: closeAll,
    stopPrice: type == 'TRAILING_STOP_MARKET' ? null : _optionalDecimal(raw['sp']),
    activatePrice: type == 'TRAILING_STOP_MARKET' ? _optionalDecimal(raw['AP']) : null,
    priceRate: type == 'TRAILING_STOP_MARKET' ? _optionalDecimal(raw['cr']) : null,
    workingType: raw['wt'] == null ? null : _choice(raw['wt'], {'MARK_PRICE', 'CONTRACT_PRICE'}),
    // Some extensions add pegPriceType; absent values preserve the REST BBO
    // flag rather than silently turning a pegged order into an ordinary limit.
    pegPriceType: raw['pegPriceType'] == null
        ? null
        : _choice(raw['pegPriceType'], {'COUNTERPARTY_1', 'QUEUE_1'}),
  );
}

String _choice(Object? value, Set<String> allowed) =>
    value is String && allowed.contains(value) ? value : throw const FormatException();
Decimal _decimal(Object? value) {
  if (value is! String || value.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

Decimal? _optionalDecimal(Object? value) => value == null ? null : _decimal(value);
bool? _bool(Object? value) =>
    value == null || value is bool ? value as bool? : throw const FormatException();
DateTime _time(Object? value) {
  if (value is! int || value <= 0 || value > 253402300799999) throw const FormatException();
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

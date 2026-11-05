import 'package:decimal/decimal.dart';

import '../../notifications/domain/account_notification.dart';
import '../domain/spot_history.dart';
import '../domain/spot_open_orders.dart';

SpotOpenOrders mapSpotOpenOrders(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
  Map<String, SpotSymbolUnits> units = const {},
}) {
  if (payload is! List || payload.length > 10000) throw const FormatException();
  final orders = <String, SpotOpenOrder>{};
  for (final value in payload) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    final symbol = _identifier(value['symbol']);
    final order = SpotOpenOrder(
      symbol: symbol,
      orderId: _id(value['orderId']),
      clientOrderId: _client(value['clientOrderId']),
      side: _side(value['side']),
      type: _code(value['type']),
      status: _code(value['status']),
      quantity: _amount(value['origQty']),
      executed: _amount(value['executedQty']),
      price: _amount(value['price']),
      quoteFilled: _amount(value['cumQuote']),
      time: _time(value['time']),
      updatedAt: _time(value['updateTime']),
      timeInForce: value['timeInForce'] == null ? null : _code(value['timeInForce']),
      originalType: value['origType'] == null ? null : _code(value['origType']),
      averagePrice: _optional(value['avgPrice']),
      stopPrice: _optional(value['stopPrice']),
      quoteOrderQuantity: _optional(value['origQuoteOrderQty']),
      units: units[symbol],
    );
    _validate(order);
    if (order.terminal) throw const FormatException();
    final previous = orders[order.key];
    if (previous != null && _canonical(previous) != _canonical(order)) {
      throw const FormatException();
    }
    orders[order.key] = order;
  }
  return SpotOpenOrders(
    address: address,
    receivedAt: receivedAt,
    orders: orders.values.toList()..sort(compareSpotOpenOrders),
    units: units,
  );
}

/// Consume the already-validated Spot execution report without assuming its
/// transaction/event clock is an order creation timestamp.
SpotOpenOrderUpdate mapSpotOpenOrderUpdate(SpotOrderNotification event, {Object? timeInForce}) {
  final order = SpotOpenOrder(
    symbol: event.symbol,
    orderId: event.orderId,
    clientOrderId: event.clientOrderId,
    side: event.side,
    type: event.orderType,
    status: event.status,
    quantity: event.quantity,
    executed: event.filledQuantity,
    price: event.price,
    quoteFilled: event.cumulativeQuoteAmount,
    averagePrice: event.averagePrice,
    stopPrice: event.stopPrice,
    quoteOrderQuantity: event.quoteOrderQuantity,
    originalType: event.originalType,
    time: event.creationMilliseconds == null || event.creationMilliseconds == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(event.creationMilliseconds!, isUtc: true),
    updatedAt: event.transactionTime,
    timeInForce: timeInForce == null ? null : _code(timeInForce),
  );
  _validate(order);
  return SpotOpenOrderUpdate(order: order, eventTime: event.eventTime);
}

void _validate(SpotOpenOrder o) {
  if (!const {
    'NEW',
    'PARTIALLY_FILLED',
    'PENDING_CANCEL',
    'FILLED',
    'CANCELED',
    'REJECTED',
    'EXPIRED',
    'EXPIRED_IN_MATCH',
  }.contains(o.status)) {
    throw const FormatException();
  }
  final quoteOnly =
      o.type == 'MARKET' && o.quoteOrderQuantity != null && o.quoteOrderQuantity! > Decimal.zero;
  if (o.quantity == Decimal.zero && !quoteOnly ||
      o.quantity > Decimal.zero && o.executed > o.quantity ||
      o.status == 'NEW' && o.executed != Decimal.zero ||
      o.status == 'PARTIALLY_FILLED' &&
          (o.executed == Decimal.zero || o.quantity > Decimal.zero && o.executed >= o.quantity) ||
      o.time != null && o.updatedAt != null && o.updatedAt!.isBefore(o.time!)) {
    throw const FormatException();
  }
}

String _canonical(SpotOpenOrder o) => [
  o.clientOrderId,
  o.side,
  o.type,
  o.status,
  o.quantity,
  o.executed,
  o.price,
  o.quoteFilled,
  o.time,
  o.updatedAt,
  o.timeInForce,
  o.originalType,
  o.averagePrice,
  o.stopPrice,
  o.quoteOrderQuantity,
].join('\u0000');
String _identifier(Object? v) =>
    v is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(v)
    ? v
    : throw const FormatException();
String _client(Object? v) => v is String && RegExp(r'^[a-zA-Z0-9_.:/-]{1,128}$').hasMatch(v)
    ? v
    : throw const FormatException();
String _side(Object? v) => v == 'BUY' || v == 'SELL' ? v! as String : throw const FormatException();
String _code(Object? v) => v is String && RegExp(r'^[A-Z][A-Z0-9_]{0,59}$').hasMatch(v)
    ? v
    : throw const FormatException();
String _id(Object? v) {
  if (v is! String && v is! int) throw const FormatException();
  final s = '$v';
  if (!RegExp(r'^(0|[1-9]\d{0,30})$').hasMatch(s)) throw const FormatException();
  return s;
}

Decimal _amount(Object? v) {
  if (v is! String || v.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(v)) {
    throw const FormatException();
  }
  return Decimal.parse(v);
}

Decimal? _optional(Object? v) => v == null ? null : _amount(v);
DateTime? _time(Object? v) {
  if (v == null || v is int && v == 0) return null;
  if (v is! int || v < 1 || v > 253402300799999) throw const FormatException();
  return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
}

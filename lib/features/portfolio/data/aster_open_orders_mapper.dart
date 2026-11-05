import 'package:decimal/decimal.dart';

import '../domain/aster_open_orders.dart';
import '../domain/aster_account.dart';

const _terminal = {'FILLED', 'CANCELED', 'REJECTED', 'EXPIRED'};
const _active = {'NEW', 'PARTIALLY_FILLED'};

AsterOpenOrders mapAsterOpenOrders(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
  Map<String, AsterContractUnits> units = const {},
}) {
  if (payload is! List<dynamic>) throw const FormatException();
  final deduplicated = <String, AsterOpenOrder>{};
  final watermarks = <String, int>{};
  for (final item in payload) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    final status = _enum(item['status']);
    if (!_terminal.contains(status) && !_active.contains(status)) {
      throw const FormatException();
    }
    final symbol = _identifier(item['symbol']);
    final orderId = _orderId(item['orderId']);
    final key = '$symbol:$orderId';
    final created = _milliseconds(item['time']);
    final updated = item['updateTime'] == null ? created : _milliseconds(item['updateTime']);
    if (updated < (watermarks[key] ?? 0)) continue;
    watermarks[key] = updated;
    if (_terminal.contains(status)) {
      deduplicated.remove(key);
      continue;
    }
    final side = _enum(item['side']);
    final positionSide = _enum(item['positionSide']);
    if (!{'BUY', 'SELL'}.contains(side) || !{'BOTH', 'LONG', 'SHORT'}.contains(positionSide)) {
      throw const FormatException();
    }
    final type = _enum(item['type']);
    final quantity = _decimal(item['origQty']);
    final executed = _decimal(item['executedQty']);
    final closePosition = _bool(item['closePosition']) ?? false;
    if (executed > quantity || (quantity == Decimal.zero && !closePosition)) {
      throw const FormatException();
    }
    final price = _decimal(item['price']);
    final order = AsterOpenOrder(
      symbol: symbol,
      orderId: orderId,
      side: side,
      positionSide: positionSide,
      type: type,
      originalType: _optionalEnum(item['origType']),
      status: status,
      time: _time(created),
      updatedAt: _time(updated),
      origQty: quantity,
      executedQty: executed,
      price: price,
      stopPrice: _optionalDecimal(item['stopPrice']),
      activatePrice: _optionalDecimal(item['activatePrice']),
      priceRate: _optionalDecimal(item['priceRate']),
      workingType: _optionalEnum(item['workingType']),
      pegPriceType: _optionalEnum(item['pegPriceType']),
      reduceOnly: _bool(item['reduceOnly']) ?? false,
      closePosition: closePosition,
      timeInForce: _optionalEnum(item['timeInForce']),
      units: units[symbol],
    );
    // Duplicate updates can appear near snapshot boundaries. Keep the last
    // order for a symbol/orderId pair; terminal rows never re-enter the list.
    deduplicated[key] = order;
  }
  final orders = deduplicated.values.toList()..sort(compareOpenOrders);
  return AsterOpenOrders(address: address, receivedAt: receivedAt, orders: orders, units: units);
}

String _identifier(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();

String _orderId(Object? value) {
  if (value is int && value > 0) return '$value';
  if (value is String && RegExp(r'^[1-9]\d{0,30}$').hasMatch(value)) return value;
  throw const FormatException();
}

String _enum(Object? value) => value is String && RegExp(r'^[A-Z][A-Z0-9_]{0,49}$').hasMatch(value)
    ? value
    : throw const FormatException();
String? _optionalEnum(Object? value) => value == null ? null : _enum(value);

Decimal _decimal(Object? value) {
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (text.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

Decimal? _optionalDecimal(Object? value) => value == null ? null : _decimal(value);
bool? _bool(Object? value) =>
    value == null || value is bool ? value as bool? : throw const FormatException();
int _milliseconds(Object? value) {
  if (value is! int || value <= 0) throw const FormatException();
  return value;
}

DateTime _time(int value) {
  try {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  } catch (_) {
    throw const FormatException();
  }
}

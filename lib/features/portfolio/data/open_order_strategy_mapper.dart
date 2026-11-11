import 'package:decimal/decimal.dart';

import '../domain/aster_open_orders.dart';

/// Reads an open `strategyOpenOrder` payload for [order]. The strategy must
/// contain [order] itself (same orderId), so a reused client ID can never
/// attach another order's exits. Legs 2/3 supply the TP/SL trigger prices.
OpenOrderStrategy mapOpenOrderStrategy(Object? payload, AsterOpenOrder order) {
  if (payload is! Map<String, dynamic>) throw const FormatException('Invalid strategy');
  final strategyId = _id(payload['strategyId']);
  final type = payload['strategyType'];
  final legs = payload['subOrders'];
  if (strategyId == null || (type != 'OTO' && type != 'OTOCO') || legs is! List) {
    throw const FormatException('Invalid strategy');
  }
  int? sequence;
  Decimal? takeProfit, stopLoss;
  for (final leg in legs) {
    if (leg is! Map<String, dynamic>) throw const FormatException('Invalid strategy leg');
    final sub = int.tryParse('${leg['strategySubId']}');
    if (sub == null || sub < 1 || sub > 3) throw const FormatException('Invalid strategy leg');
    if (_id(leg['orderId']) == order.orderId && leg['symbol'] == order.symbol) sequence = sub;
    if (sub == 1) continue;
    final stop = leg['stopPrice'] is String ? Decimal.tryParse(leg['stopPrice'] as String) : null;
    if (stop == null || stop <= Decimal.zero) continue;
    final kind = '${leg['origType'] ?? leg['type']}';
    if (kind.startsWith('TAKE_PROFIT')) {
      takeProfit = stop;
    } else if (kind.startsWith('STOP')) {
      stopLoss = stop;
    }
  }
  if (sequence == null) throw const FormatException('Strategy does not contain the order');
  return OpenOrderStrategy(
    strategyId: strategyId,
    type: type as String,
    sequence: sequence,
    takeProfit: takeProfit,
    stopLoss: stopLoss,
  );
}

String? _id(Object? value) {
  if (value is int && value > 0) return '$value';
  if (value is String && RegExp(r'^[1-9]\d{0,30}$').hasMatch(value)) return value;
  return null;
}

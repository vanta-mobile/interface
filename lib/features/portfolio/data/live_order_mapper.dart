import 'package:decimal/decimal.dart';

import '../domain/live_order.dart';
import '../domain/order_query.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/futures_position_mode.dart';
import 'position_configuration_rows.dart';

Decimal _amount(Object? value, {bool positive = false}) {
  if (value is! String || value.length > 80 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Invalid exchange decimal');
  }
  final amount = Decimal.parse(value);
  if (positive ? amount <= Decimal.zero : amount < Decimal.zero) {
    throw const FormatException('Invalid exchange decimal');
  }
  return amount;
}

LiveOrderRules mapLiveOrderRules(Object? payload, String symbol) {
  validatePositionSymbol(symbol);
  if (payload is! Map<String, dynamic> || payload['symbols'] is! List) {
    throw const FormatException('Missing exchange symbols');
  }
  final matches = (payload['symbols'] as List)
      .where((item) => item is Map<String, dynamic> && item['symbol'] == symbol)
      .toList();
  if (matches.length != 1) throw const FormatException('Missing symbol');
  final row = matches.single as Map<String, dynamic>;
  final precision = row['pricePrecision'];
  if (precision != null && (precision is! int || precision < 0 || precision > 80)) {
    throw const FormatException('Invalid price precision');
  }
  if (row['status'] != 'TRADING' ||
      row['contractType'] != 'PERPETUAL' ||
      row['baseAsset'] is! String ||
      row['quoteAsset'] != 'USDT' ||
      row['marginAsset'] != 'USDT' ||
      row['orderTypes'] is! List ||
      !(row['orderTypes'] as List).contains('LIMIT') ||
      !(row['orderTypes'] as List).contains('MARKET') ||
      row['filters'] is! List) {
    throw const FormatException('Symbol not trading');
  }
  validatePositionSymbol(row['baseAsset'] as String);
  final orderTypes = row['orderTypes'] as List;
  if (orderTypes.any((value) => value is! String || !RegExp(r'^[A-Z_]{1,40}$').hasMatch(value)) ||
      orderTypes.toSet().length != orderTypes.length) {
    throw const FormatException('Invalid order capabilities');
  }
  final policies = row['timeInForce'];
  if (policies is! List ||
      policies.isEmpty ||
      policies.any(
        (value) => value is! String || !RegExp(r'^[A-Z][A-Z0-9_]{0,31}$').hasMatch(value),
      ) ||
      policies.toSet().length != policies.length) {
    throw const FormatException('Invalid time in force capabilities');
  }
  final filters = <String, Map<String, dynamic>>{};
  for (final item in row['filters'] as List) {
    if (item is! Map<String, dynamic> || item['filterType'] is! String) {
      throw const FormatException('Invalid filter');
    }
    final type = item['filterType'] as String;
    if (filters.containsKey(type)) throw const FormatException('Duplicate filter');
    filters[type] = item;
  }
  Map<String, dynamic> requiredFilter(String type) =>
      filters[type] ?? (throw const FormatException('Missing filter'));
  final price = requiredFilter('PRICE_FILTER');
  OrderQuantityRule quantity(String type) {
    final row = requiredFilter(type);
    final minimum = _amount(row['minQty'], positive: true);
    final maximum = _amount(row['maxQty'], positive: true);
    final step = _amount(row['stepSize'], positive: true);
    if (minimum > maximum) throw const FormatException('Invalid quantity bounds');
    return OrderQuantityRule(minimum: minimum, maximum: maximum, step: step);
  }

  final minimum = _amount(price['minPrice']);
  final maximum = _amount(price['maxPrice']);
  if (maximum > Decimal.zero && maximum < minimum) {
    throw const FormatException('Invalid price bounds');
  }
  final percent = requiredFilter('PERCENT_PRICE');
  final up = _amount(percent['multiplierUp'], positive: true);
  final down = _amount(percent['multiplierDown'], positive: true);
  if (down > up) throw const FormatException('Invalid percent bounds');
  return LiveOrderRules(
    symbol: symbol,
    baseAsset: row['baseAsset'] as String,
    quoteAsset: row['quoteAsset'] as String,
    priceMinimum: minimum,
    priceMaximum: maximum,
    priceTick: _amount(price['tickSize']),
    pricePrecision: precision as int?,
    limitQuantity: quantity('LOT_SIZE'),
    marketQuantity: quantity('MARKET_LOT_SIZE'),
    minimumNotional: _amount(requiredFilter('MIN_NOTIONAL')['notional']),
    percentUp: up,
    percentDown: down,
    orderTypes: orderTypes.cast<String>().toSet(),
    triggerProtect: row['triggerProtect'] == null ? null : _amount(row['triggerProtect']),
    timeInForce: LiveOrderTimeInForce.values
        .where((value) => policies.contains(value.wire))
        .toSet(),
  );
}

Decimal mapLiveMarkPrice(Object? payload, String symbol, int serverMilliseconds) {
  if (payload is! Map<String, dynamic> ||
      payload['symbol'] != symbol ||
      payload['time'] is! int ||
      ((payload['time'] as int) - serverMilliseconds).abs() > 10000) {
    throw const FormatException('Invalid mark symbol');
  }
  return _amount(payload['markPrice'], positive: true);
}

Decimal mapLiveLastPrice(Object? payload, String symbol, int serverMilliseconds) {
  // Ticker time is the last trade time, not the response time. A quiet market
  // can legitimately have an older last trade; it is not a mark-price timestamp.
  if (payload is! Map<String, dynamic> ||
      payload['symbol'] != symbol ||
      payload['time'] is! int ||
      (payload['time'] as int) < 0 ||
      (payload['time'] as int) > serverMilliseconds + 10000) {
    throw const FormatException('Invalid last-price ticker');
  }
  return _amount(payload['price'], positive: true);
}

Map<String, LiveOrderPosition> mapLiveOrderPositions(
  Object? payload,
  String symbol,
  FuturesPositionMode mode,
) {
  final rows = positionConfigurationRows(payload, symbol);
  if ((mode == FuturesPositionMode.oneWay) != (rows.singleOrNull?['positionSide'] == 'BOTH')) {
    throw const FormatException('Conflicting position mode');
  }
  final result = <String, LiveOrderPosition>{};
  for (final row in rows) {
    final raw = row['positionAmt'];
    if (raw is! String || raw.length > 80 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(raw)) {
      throw const FormatException('Invalid position amount');
    }
    final amount = Decimal.parse(raw), side = row['positionSide'] as String;
    if (side == 'LONG' && amount < Decimal.zero || side == 'SHORT' && amount > Decimal.zero) {
      throw const FormatException('Conflicting position direction');
    }
    result[side] = LiveOrderPosition(
      side: side,
      quantity: amount,
      entryPrice: _amount(row['entryPrice'], positive: amount != Decimal.zero),
    );
  }
  return Map.unmodifiable(result);
}

({Decimal bid, Decimal ask}) mapLiveCloseBook(Object? payload, String symbol) {
  if (payload is! Map<String, dynamic> || payload['symbol'] != symbol) {
    throw const FormatException('Invalid book symbol');
  }
  final bid = _amount(payload['bidPrice'], positive: true);
  final ask = _amount(payload['askPrice'], positive: true);
  _amount(payload['bidQty'], positive: true);
  _amount(payload['askQty'], positive: true);
  if (bid > ask) throw const FormatException('Crossed book');
  return (bid: bid, ask: ask);
}

LiveOrderResult mapLiveOrderQuery(Object? payload, LiveOrderIntent intent, {DateTime? checkedAt}) =>
    mapRecoveredOrderQuery(payload, OrderQuery.capture(intent), checkedAt: checkedAt);

LiveOrderResult mapRecoveredOrderQuery(Object? payload, OrderQuery intent, {DateTime? checkedAt}) {
  if (intent.draft.attachment != null) {
    throw const FormatException('Strategy order requires strategy query');
  }
  if (payload is! Map<String, dynamic>) throw const FormatException('Invalid order payload');
  final peg = payload['pegPriceType'];
  if (intent.draft.peg == null ? peg != null && peg != '' : peg != intent.draft.peg!.wire) {
    throw const FormatException('Order peg mismatch');
  }
  if (intent.draft.peg != null &&
      (payload['reduceOnly'] !=
              (intent.draft.reducing && intent.mode == FuturesPositionMode.oneWay) ||
          payload['closePosition'] != false)) {
    throw const FormatException('BBO order scope mismatch');
  }
  if (payload['symbol'] != intent.symbol ||
      payload['clientOrderId'] != intent.clientOrderId ||
      payload['side'] != intent.side ||
      payload['positionSide'] != intent.positionSide ||
      intent.draft.reducing &&
          payload['reduceOnly'] !=
              (!intent.draft.entireClose && intent.mode == FuturesPositionMode.oneWay) ||
      intent.draft.reducing && payload['closePosition'] != intent.draft.entireClose ||
      (intent.draft.trigger == null && intent.draft.trailing == null
          ? payload['type'] != intent.draft.orderType
          : payload['origType'] != intent.draft.orderType ||
                !{
                  intent.draft.orderType,
                  intent.draft.market ? 'MARKET' : 'LIMIT',
                }.contains(payload['type']))) {
    throw const FormatException('Order identity mismatch');
  }
  if (intent.draft.quickEntry &&
      (payload['reduceOnly'] != false || payload['closePosition'] != false)) {
    throw const FormatException('Quick order scope mismatch');
  }
  if (intent.draft.trigger case final trigger?) {
    if (_amount(payload['stopPrice'], positive: true) != parseOrderDecimal(trigger.price) ||
        payload['workingType'] != trigger.basis.wire ||
        payload['priceProtect'] != trigger.protect ||
        payload['reduceOnly'] !=
            (!intent.draft.entireClose &&
                intent.draft.reducing &&
                intent.mode == FuturesPositionMode.oneWay) ||
        payload['closePosition'] != intent.draft.entireClose ||
        intent.draft.market && payload['timeInForce'] != 'GTC') {
      throw const FormatException('Conditional order terms mismatch');
    }
  }
  if (intent.draft.trailing case final trailing?) {
    final activation = _amount(payload['activatePrice'], positive: true);
    if (_amount(payload['priceRate'], positive: true) != parseOrderDecimal(trailing.callbackRate) ||
        trailing.activationPrice != null &&
            activation != parseOrderDecimal(trailing.activationPrice!) ||
        payload['workingType'] != trailing.basis.wire ||
        payload['reduceOnly'] !=
            (intent.draft.reducing && intent.mode == FuturesPositionMode.oneWay) ||
        payload['closePosition'] != false ||
        payload['timeInForce'] != 'GTC') {
      throw const FormatException('Trailing order terms mismatch');
    }
  }
  final id = '${payload['orderId']}';
  final status = payload['status'];
  if (!RegExp(r'^[1-9]\d{0,30}$').hasMatch(id) ||
      status is! String ||
      !const {
        'NEW',
        'PARTIALLY_FILLED',
        'FILLED',
        'CANCELED',
        'EXPIRED',
        'REJECTED',
        'EXPIRED_IN_MATCH',
      }.contains(status)) {
    throw const FormatException('Invalid order status');
  }
  final observedPrice = intent.draft.market ? null : _amount(payload['price']);
  final requested = _amount(payload['origQty'], positive: !intent.draft.entireClose);
  final executed = _amount(payload['executedQty']);
  if ((!intent.draft.entireClose && requested != parseOrderDecimal(intent.draft.quantity)) ||
      (!intent.draft.entireClose || requested > Decimal.zero) && executed > requested ||
      status == 'FILLED' &&
          (executed <= Decimal.zero ||
              (!intent.draft.entireClose || requested > Decimal.zero) && executed != requested) ||
      status == 'NEW' && executed != Decimal.zero ||
      status == 'PARTIALLY_FILLED' &&
          (executed <= Decimal.zero ||
              (!intent.draft.entireClose || requested > Decimal.zero) && executed >= requested) ||
      !intent.draft.market &&
          (intent.draft.peg == null && observedPrice != parseOrderDecimal(intent.draft.price) ||
              payload['timeInForce'] != intent.draft.timeInForce.wire)) {
    throw const FormatException('Invalid order quantity');
  }
  return LiveOrderResult(
    orderId: id,
    status: status,
    executedQuantity: executed,
    checkedAt: checkedAt,
  );
}

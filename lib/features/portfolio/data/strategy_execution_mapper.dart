import 'package:decimal/decimal.dart';

import '../domain/attached_order.dart';
import '../domain/live_order.dart';
import '../domain/strategy_execution.dart';

Decimal _amount(Object? value) {
  if (value is! String) throw const FormatException('Missing execution decimal');
  final amount = parseOrderDecimal(value);
  if (amount == null) throw const FormatException('Invalid execution decimal');
  return amount;
}

DateTime _time(Object? value) {
  if (value is! int || value < 0 || value > 10413792000000) {
    throw const FormatException('Invalid execution time');
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

StrategyLegExecution mapStrategyLegExecution(
  Object? payload, {
  required StrategyExecutionQuery query,
  required int sequence,
  required String orderId,
  required DateTime checkedAt,
}) {
  final terms = buildStrategyLegs(query.order)
      .where((r) => r['strategySubId'] == '$sequence')
      .single;
  if (payload is! Map<String, dynamic> ||
      payload['orderId'] is! int && payload['orderId'] is! String ||
      '${payload['orderId']}' != orderId ||
      payload['clientOrderId'] != terms['clientOrderId'] ||
      payload['symbol'] != terms['symbol'] ||
      payload['side'] != terms['side'] ||
      payload['positionSide'] != terms['positionSide'] ||
      payload['reduceOnly'] != (terms['reduceOnly'] == 'true') ||
      payload['closePosition'] != false ||
      payload['origType'] != terms['type'] ||
      payload['timeInForce'] != (terms['timeInForce'] ?? 'GTC')) {
    throw const FormatException('Execution identity mismatch');
  }
  final type = payload['type'];
  final conditional = terms.containsKey('stopPrice');
  if (type != terms['type'] &&
      !(conditional && type == (terms.containsKey('price') ? 'LIMIT' : 'MARKET'))) {
    throw const FormatException('Execution type mismatch');
  }
  final status = payload['status'];
  if (status is! String ||
      !const {
        'NEW',
        'PARTIALLY_FILLED',
        'FILLED',
        'CANCELED',
        'EXPIRED',
        'REJECTED',
        'EXPIRED_IN_MATCH',
        'PENDING_CANCEL',
      }.contains(status)) {
    throw const FormatException('Invalid execution status');
  }
  final quantity = _amount(payload['origQty']), executed = _amount(payload['executedQty']);
  final price = _amount(payload['price']);
  final quote = payload['cumQuote'] == null ? null : _amount(payload['cumQuote']);
  final average = payload['avgPrice'] == null ? null : _amount(payload['avgPrice']);
  if (quantity <= Decimal.zero ||
      executed > quantity ||
      status == 'NEW' && executed != Decimal.zero ||
      status == 'PARTIALLY_FILLED' && (executed <= Decimal.zero || executed >= quantity) ||
      status == 'FILLED' && (executed <= Decimal.zero || executed != quantity) ||
      executed == Decimal.zero &&
          (quote != null && quote != Decimal.zero || average != null && average != Decimal.zero) ||
      executed > Decimal.zero &&
          (quote != null && quote <= Decimal.zero || average != null && average <= Decimal.zero)) {
    throw const FormatException('Inconsistent execution amounts');
  }
  final created = _time(payload['time']), updated = _time(payload['updateTime']);
  if (updated.isBefore(created)) throw const FormatException('Execution times reversed');
  var changed = quantity != parseOrderDecimal(terms['quantity']!);
  // Ordinary BBO orders can expose an engine-resolved price. The signed
  // strategy and both order IDs establish the peg; never compare it to zero.
  final peg = payload['pegPriceType'];
  if (peg != null && peg != '' && peg != terms['pegPriceType']) {
    throw const FormatException('Execution peg mismatch');
  }
  if (terms.containsKey('price') && !terms.containsKey('pegPriceType')) {
    changed |= price != parseOrderDecimal(terms['price']!);
  }
  if (conditional) {
    changed |= _amount(payload['stopPrice']) != parseOrderDecimal(terms['stopPrice']!);
    if (payload['workingType'] != terms['workingType'] ||
        payload['priceProtect'] != (terms['priceProtect'] == 'true')) {
      throw const FormatException('Execution trigger basis mismatch');
    }
  }
  return StrategyLegExecution(
    orderId: orderId,
    status: status,
    type: type as String,
    originalType: terms['type']!,
    quantity: quantity,
    executed: executed,
    price: price,
    quoteAmount: quote,
    averagePrice: average,
    createdAt: created,
    updatedAt: updated,
    checkedAt: checkedAt,
    termsChanged: changed,
  );
}

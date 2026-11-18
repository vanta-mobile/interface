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
  // The exchange order ID identifies the leg. Aster may normalize its type,
  // policy and flags; those differences are not treated as a failure.
  if (payload is! Map<String, dynamic> ||
      payload['orderId'] is! int && payload['orderId'] is! String ||
      '${payload['orderId']}' != orderId ||
      payload['symbol'] != terms['symbol'] ||
      payload['side'] != terms['side']) {
    throw const FormatException('Execution identity mismatch');
  }
  final type = payload['type'];
  if (type is! String || type.isEmpty) throw const FormatException('Invalid execution type');
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
  // Ordinary BBO orders can expose an engine-resolved price; never compare
  // it to the zero sentinel. Other differences are reported, not rejected.
  if (terms.containsKey('price') && !terms.containsKey('pegPriceType')) {
    changed |= price != parseOrderDecimal(terms['price']!);
  }
  if (terms['stopPrice'] case final stopPrice?) {
    changed |= parseOrderDecimal('${payload['stopPrice']}') != parseOrderDecimal(stopPrice);
  }
  return StrategyLegExecution(
    orderId: orderId,
    status: status,
    type: type,
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

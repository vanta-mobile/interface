import '../domain/account_snapshot.dart';
import '../domain/attached_order.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/order_query.dart';

String _status(Object? value) {
  if (value is! String || !RegExp(r'^[A-Z][A-Z0-9_]{0,39}$').hasMatch(value)) {
    throw const FormatException('Invalid strategy status');
  }
  return value;
}

String? _orderId(Object? value) {
  if (value == null || value == 0 || value == '0') return null;
  if (value is! int && value is! String || !RegExp(r'^[1-9]\d{0,30}$').hasMatch('$value')) {
    throw const FormatException('Invalid strategy leg order ID');
  }
  return '$value';
}

/// Read failureCode even on HTTP 200. The raw server reason is never displayed.
void checkAttachedOrderAcknowledgement(Object? payload) {
  if (payload is! Map<String, dynamic> || payload['failureCode'] is! int) {
    throw const AccountReadFailure('accountDataInvalid');
  }
  if (payload['failureCode'] != 0) {
    throw AccountReadFailure('attachedOrderRejected', code: payload['failureCode'] as int);
  }
}

LiveOrderResult mapAttachedOrderQuery(
  Object? payload,
  LiveOrderIntent intent,
  DateTime checkedAt,
) => mapRecoveredStrategyQuery(payload, OrderQuery.capture(intent), checkedAt);

LiveOrderResult mapRecoveredStrategyQuery(Object? payload, OrderQuery intent, DateTime checkedAt) {
  final expected = buildStrategyLegs(intent);
  if (payload is! Map<String, dynamic> ||
      payload['clientStrategyId'] != intent.clientOrderId ||
      payload['strategyType'] != intent.draft.attachment!.strategyType ||
      payload['subOrders'] is! List ||
      (payload['subOrders'] as List).length != expected.length) {
    throw const FormatException('Strategy identity mismatch');
  }
  final strategyId = _orderId(payload['strategyId']);
  if (strategyId == null) throw const FormatException('Missing strategy ID');
  final rows = <int, Map<String, dynamic>>{};
  for (final item in payload['subOrders'] as List) {
    if (item is! Map<String, dynamic>) throw const FormatException('Invalid strategy leg');
    final rawSequence = item['strategySubId'];
    if (rawSequence is! String && rawSequence is! int ||
        !RegExp(r'^[1-3]$').hasMatch('$rawSequence')) {
      throw const FormatException('Invalid strategy sequence');
    }
    final sequence = int.parse('$rawSequence');
    if (rows.containsKey(sequence)) throw const FormatException('Duplicate strategy sequence');
    rows[sequence] = item;
  }
  final ids = <String>{};
  final legs = <AttachedOrderLeg>[];
  for (final terms in expected) {
    final sequence = int.parse(terms['strategySubId']!);
    final row = rows[sequence];
    if (row == null ||
        _orderId(row['strategyId']) != strategyId ||
        !{'USDT_FUTURES', 'FUTURE'}.contains(row['securityType']) ||
        row['symbol'] != terms['symbol'] ||
        row['side'] != terms['side'] ||
        row['positionSide'] != terms['positionSide'] ||
        row['clientOrderId'] != terms['clientOrderId'] ||
        row['reduceOnly'] != (terms['reduceOnly'] == 'true') ||
        row['closePosition'] != false) {
      throw const FormatException('Strategy leg identity mismatch');
    }
    // A zero price alone never proves BBO identity. Also reject an unexpected
    // peg on fixed-price entries/exits; otherwise a different strategy could be
    // reported as verified even when its numeric price happens to match.
    final peg = row['pegPriceType'];
    if (terms.containsKey('pegPriceType')
        ? peg != terms['pegPriceType']
        : peg != null && peg != '') {
      throw const FormatException('Strategy peg mismatch');
    }
    final conditional = terms.containsKey('stopPrice');
    if (row['type'] != terms['type'] &&
        !(conditional &&
            row['origType'] == terms['type'] &&
            row['type'] == (terms.containsKey('price') ? 'LIMIT' : 'MARKET'))) {
      throw const FormatException('Strategy leg type mismatch');
    }
    for (final key in ['quantity', 'price', 'stopPrice']) {
      if (terms[key] case final text?) {
        final value = row[key];
        if (value is! String ||
            parseOrderDecimal(value) == null ||
            parseOrderDecimal(value) != parseOrderDecimal(text)) {
          throw const FormatException('Strategy decimal mismatch');
        }
      }
    }
    if (row['timeInForce'] != (terms['timeInForce'] ?? 'GTC') ||
        row['workingType'] != (terms['workingType'] ?? 'CONTRACT_PRICE') ||
        row['priceProtect'] != (terms['priceProtect'] == 'true')) {
      throw const FormatException('Strategy leg policy mismatch');
    }
    for (final prefix in ['first', 'second']) {
      final driver = terms['${prefix}DrivenId'];
      final actualDriver = row['${prefix}DrivenId'];
      if (actualDriver is! int && actualDriver is! String ||
          '$actualDriver' != (driver ?? '0') ||
          row['${prefix}DrivenOn'] != (terms['${prefix}DrivenOn'] ?? '') ||
          row['${prefix}Trigger'] != (terms['${prefix}Trigger'] ?? '')) {
        throw const FormatException('Strategy linkage mismatch');
      }
    }
    final id = _orderId(row['orderId']);
    if (id != null && !ids.add(id)) throw const FormatException('Duplicate leg order ID');
    legs.add(AttachedOrderLeg(sequence: sequence, status: _status(row['status']), orderId: id));
  }
  return LiveOrderResult(
    checkedAt: checkedAt,
    strategy: AttachedOrderSnapshot(
      strategyId: strategyId,
      status: _status(payload['strategyStatus']),
      legs: legs,
    ),
  );
}

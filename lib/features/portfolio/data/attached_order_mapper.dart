import '../domain/account_snapshot.dart';
import '../domain/attached_order.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/order_query.dart';
import '../../../core/errors/api_error_details.dart';

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
    throw const AccountReadFailure(
      'accountDataInvalid',
      reasonKey: 'orderAcknowledgementInvalid',
      details: ApiErrorDetails(
        cause: ApiErrorCause.invalidResponse,
        endpoint: '/fapi/v3/placeStrategyOrder',
      ),
    );
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

/// A successful `placeStrategyOrder` response is the placement evidence. It
/// carries no legs, so leg details stay with the explicit strategy reads.
/// Returns null when the response cannot be tied to this submission.
LiveOrderResult? mapStrategyAcknowledgement(
  Object? payload,
  OrderQuery intent,
  DateTime checkedAt,
) {
  if (payload is! Map<String, dynamic> ||
      payload['failureCode'] != 0 ||
      payload['clientStrategyId'] != intent.clientOrderId ||
      payload['strategyType'] != intent.draft.attachment!.strategyType) {
    return null;
  }
  try {
    final strategyId = _orderId(payload['strategyId']);
    if (strategyId == null) return null;
    return LiveOrderResult(
      checkedAt: checkedAt,
      strategy: AttachedOrderSnapshot(
        strategyId: strategyId,
        status: _status(payload['strategyStatus']),
        legs: const [],
      ),
    );
  } on FormatException {
    return null;
  }
}

/// Confirms that [payload] is the strategy placed under the frozen client
/// strategy ID and reads each leg's status and order ID. Leg terms are not
/// compared: Aster may normalize types, prices and policies, and a difference
/// there must not turn an accepted strategy into a reported failure.
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
        row['symbol'] != terms['symbol'] ||
        row['side'] != terms['side']) {
      throw const FormatException('Strategy leg identity mismatch');
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

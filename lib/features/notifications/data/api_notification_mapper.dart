import 'package:decimal/decimal.dart';

import '../domain/api_notification.dart';

ApiNotificationPage mapNotificationPage(Map<String, Object?> json) {
  final items = json['items'], cursor = json['next_cursor'], unread = json['unread'];
  final capped = json['unread_count_capped'];
  if (items is! List ||
      !json.containsKey('next_cursor') ||
      (cursor != null && (cursor is! String || cursor.isEmpty)) ||
      unread is! int ||
      unread < 0 ||
      capped != null && capped is! bool ||
      capped == true && unread < 100) {
    throw const FormatException('notification page');
  }
  return ApiNotificationPage(
    items: items.map((e) {
      if (e is! Map<String, Object?>) throw const FormatException('notification');
      return mapApiNotification(e);
    }),
    nextCursor: cursor as String?,
    unread: unread,
    unreadCountCapped: capped == true,
  );
}

ApiNotification mapApiNotification(Map<String, Object?> json) {
  final kind = switch (json['kind']) {
    'event' => ApiNotificationKind.event,
    'broadcast' => ApiNotificationKind.broadcast,
    _ => throw const FormatException('kind'),
  };
  final type = switch (json['type']) {
    'FILL' => ApiNotificationType.fill,
    'TRIGGER' => ApiNotificationType.trigger,
    'ORDER' => ApiNotificationType.order,
    'LIQUIDATION' => ApiNotificationType.liquidation,
    'MARGIN_CALL' => ApiNotificationType.marginCall,
    'FUNDING' => ApiNotificationType.funding,
    'TRANSFER' => ApiNotificationType.transfer,
    'ANNOUNCE' => ApiNotificationType.announce,
    'MAINTENANCE' => ApiNotificationType.maintenance,
    _ => throw const FormatException('type'),
  };
  final broadcast = type == ApiNotificationType.announce || type == ApiNotificationType.maintenance;
  if (broadcast != (kind == ApiNotificationKind.broadcast)) {
    throw const FormatException('kind/type');
  }
  final severity = ApiNotificationSeverity.values
      .where((e) => e.name == json['severity'])
      .firstOrNull;
  final id = json['id'], read = json['read'], payload = json['payload'];
  if (id is! int ||
      id < 0 ||
      read is! bool ||
      severity == null ||
      payload is! Map<String, Object?>) {
    throw const FormatException('notification fields');
  }
  return ApiNotification(
    kind: kind,
    id: id,
    key: _text(json['event_key']),
    type: type,
    severity: severity,
    read: read,
    symbol: _optional(json['symbol'] ?? payload['symbol']),
    createdAt: _time(json['created_at']),
    readAt: json['read_at'] == null ? null : _time(json['read_at']),
    payload: _payload(payload),
  );
}

NotificationPayload _payload(Map<String, Object?> p) => NotificationPayload(
  title: _optional(p['title']),
  message: _optional(p['message']),
  market: _choice(p['market'], const ['spot', 'futures', 'perp']),
  status: _choice(p['status'], const [
    'NEW',
    'PARTIALLY_FILLED',
    'FILLED',
    'CANCELED',
    'EXPIRED',
    'REJECTED',
    'processing',
    'success',
    'failed',
  ]),
  side: _choice(p['side'], const ['BUY', 'SELL']),
  asset: _optional(p['asset']),
  baseAsset: _optional(p['base_asset']),
  quoteAsset: _optional(p['quote_asset']),
  feeAsset: _optional(p['fee_asset']),
  orderId: _reference(p['order_id']),
  transactionHash: _optional(p['tx_hash']),
  tradeId: _reference(p['trade_id']),
  clientOrderId: _optional(p['client_order_id']),
  reference: _optional(p['reference']),
  positionSide: _choice(p['position_side'], const ['LONG', 'SHORT', 'BOTH']),
  transferKind: _choice(p['kind'], const ['deposit', 'withdraw', 'internal_transfer']),
  source: _choice(p['source'], const ['report']),
  orderType: _optional(p['order_type']),
  originalType: _optional(p['orig_type']),
  network: _optional(p['network']),
  numbers: {
    for (final field in const {
      'price': NotificationNumber.price,
      'qty': NotificationNumber.quantity,
      'fee': NotificationNumber.fee,
      'mark_price': NotificationNumber.markPrice,
      'liquidation_price': NotificationNumber.liquidationPrice,
      'distance': NotificationNumber.distance,
      'amount': NotificationNumber.amount,
      'executed_qty': NotificationNumber.executedQuantity,
      'avg_price': NotificationNumber.averagePrice,
    }.entries)
      if (p[field.key] != null) field.value: _decimal(p[field.key]),
  },
);

String _text(Object? value) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > 8192 ||
      RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]').hasMatch(value)) {
    throw const FormatException('text');
  }
  return value;
}

String? _optional(Object? value) => value == null ? null : _text(value);
String? _reference(Object? value) => value is int && value >= 0 ? '$value' : _optional(value);
String? _choice(Object? value, List<String> choices) {
  final text = _optional(value);
  // An unrecognized optional enum is not a known financial fact.
  return choices.contains(text) ? text : null;
}

Decimal _decimal(Object? value) {
  // Decimal strings preserve financial precision. Integer JSON values are exact.
  final text = value is int ? '$value' : value;
  if (text is! String ||
      text.length > 80 ||
      !RegExp(r'^-?\d+(\.\d+)?(?:[eE][+-]?\d{1,3})?$').hasMatch(text)) {
    throw const FormatException('decimal');
  }
  final parts = text.split(RegExp('[eE]'));
  if (parts.length > 1 && int.parse(parts.last).abs() > 80) {
    throw const FormatException('decimal exponent');
  }
  return Decimal.parse(text);
}

DateTime _time(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('timestamp');
  }
  final time = DateTime.tryParse(value);
  if (time == null) throw const FormatException('timestamp');
  return time.toUtc();
}

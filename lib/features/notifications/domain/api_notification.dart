import 'package:decimal/decimal.dart';

/// The backend inbox has its own identity/read state. Local Aster journals are
/// deliberately separate: their contents are not evidence of server delivery.
enum ApiNotificationKind { event, broadcast }

enum ApiNotificationType {
  fill,
  trigger,
  order,
  liquidation,
  marginCall,
  funding,
  transfer,
  announce,
  maintenance,
}

enum ApiNotificationSeverity { critical, high, medium, low }

/// What `/v1/notifications/read` needs to mark one entry: events by key,
/// broadcasts by id (a cursor that only moves forward).
class ApiNotificationReadTarget {
  const ApiNotificationReadTarget.event(String this.key, {required this.id})
    : kind = ApiNotificationKind.event;
  const ApiNotificationReadTarget.broadcast(this.id)
    : kind = ApiNotificationKind.broadcast,
      key = null;
  final ApiNotificationKind kind;
  final int id;
  final String? key;
}

enum NotificationNumber {
  price,
  quantity,
  fee,
  markPrice,
  liquidationPrice,
  distance,
  amount,
  executedQuantity,
  averagePrice,
}

class NotificationPayload {
  NotificationPayload({
    this.title,
    this.message,
    this.market,
    this.status,
    this.side,
    this.asset,
    this.baseAsset,
    this.quoteAsset,
    this.feeAsset,
    this.orderId,
    this.transactionHash,
    this.tradeId,
    this.clientOrderId,
    this.reference,
    this.positionSide,
    this.transferKind,
    this.source,
    this.orderType,
    this.originalType,
    this.network,
    Map<NotificationNumber, Decimal> numbers = const {},
  }) : numbers = Map.unmodifiable(numbers);
  final String? title, message, market, status, side;
  final String? asset, baseAsset, quoteAsset, feeAsset, orderId, transactionHash;
  final String? tradeId, clientOrderId, reference, positionSide, transferKind, source;
  final String? orderType, originalType, network;
  final Map<NotificationNumber, Decimal> numbers;
}

class NotificationSymbolUnits {
  const NotificationSymbolUnits({this.base, this.quote});
  final String? base, quote;
}

class ApiNotification {
  const ApiNotification({
    required this.kind,
    required this.id,
    required this.key,
    required this.type,
    required this.severity,
    required this.payload,
    required this.read,
    required this.createdAt,
    this.symbol,
    this.readAt,
  });
  final ApiNotificationKind kind;
  final int id;
  final String key;
  final ApiNotificationType type;
  final ApiNotificationSeverity severity;
  final NotificationPayload payload;
  final bool read;
  final DateTime createdAt;
  final String? symbol;
  final DateTime? readAt;
  ApiNotificationReadTarget get readTarget => kind == ApiNotificationKind.event
      ? ApiNotificationReadTarget.event(key, id: id)
      : ApiNotificationReadTarget.broadcast(id);

  ApiNotification asRead() => ApiNotification(
    kind: kind,
    id: id,
    key: key,
    type: type,
    severity: severity,
    payload: payload,
    read: true,
    createdAt: createdAt,
    symbol: symbol,
    readAt: readAt,
  );
}

class ApiNotificationPage {
  ApiNotificationPage({
    required Iterable<ApiNotification> items,
    required this.nextCursor,
    required this.unread,
    this.unreadCountCapped = false,
  }) : items = List.unmodifiable(items);
  final List<ApiNotification> items;
  final String? nextCursor;
  final int unread;
  final bool unreadCountCapped;
}

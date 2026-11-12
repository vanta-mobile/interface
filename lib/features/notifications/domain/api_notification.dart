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

enum NotificationNumber { price, quantity, fee, markPrice, liquidationPrice, distance, amount }

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
    Map<NotificationNumber, Decimal> numbers = const {},
  }) : numbers = Map.unmodifiable(numbers);
  final String? title, message, market, status, side;
  final String? asset, baseAsset, quoteAsset, feeAsset, orderId, transactionHash;
  final Map<NotificationNumber, Decimal> numbers;
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
  }) : items = List.unmodifiable(items);
  final List<ApiNotification> items;
  final String? nextCursor;
  final int unread;
}

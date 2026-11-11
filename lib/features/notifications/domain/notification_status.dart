import '../../funding/domain/transfer_history.dart';
import 'account_notification.dart';

/// Design status icon (Figma `328:29680`); chip tone is chosen separately.
enum NotificationStatusIcon { info, success, failed, warning, pending }

enum NotificationTone { neutral, positive, warning, negative }

/// Inbox tabs: margin-risk events only appear under "All".
enum NotificationFilter { all, transfers, orders }

NotificationStatusIcon notificationStatusIcon(AccountNotification event) => switch (event) {
  TransferNotification(:final record) => switch (record.status) {
    TransferStatus.processing => NotificationStatusIcon.pending,
    TransferStatus.success => NotificationStatusIcon.success,
    TransferStatus.failed => NotificationStatusIcon.failed,
  },
  MarginNotification() ||
  OrderNotification(risk: OrderRisk.liquidation) => NotificationStatusIcon.warning,
  OrderNotification(risk: OrderRisk.adl) => NotificationStatusIcon.info,
  OrderNotification(:final status) || SpotOrderNotification(:final status) => switch (status) {
    'NEW' => NotificationStatusIcon.pending,
    'FILLED' || 'PARTIALLY_FILLED' => NotificationStatusIcon.success,
    'REJECTED' => NotificationStatusIcon.failed,
    _ => NotificationStatusIcon.info,
  },
};

NotificationTone notificationTone(AccountNotification event) => switch (event) {
  TransferNotification(:final record) => switch (record.status) {
    TransferStatus.processing => NotificationTone.warning,
    TransferStatus.success => NotificationTone.positive,
    TransferStatus.failed => NotificationTone.negative,
  },
  MarginNotification() ||
  OrderNotification(risk: OrderRisk.liquidation) => NotificationTone.negative,
  OrderNotification(risk: OrderRisk.adl) => NotificationTone.warning,
  OrderNotification(:final status) || SpotOrderNotification(:final status) => _orderTone(status),
};

NotificationTone _orderTone(String status) => switch (status) {
  'FILLED' => NotificationTone.positive,
  'PARTIALLY_FILLED' || 'EXPIRED' => NotificationTone.warning,
  'REJECTED' => NotificationTone.negative,
  _ => NotificationTone.neutral,
};

bool notificationMatches(NotificationFilter filter, AccountNotification event) => switch (filter) {
  NotificationFilter.all => true,
  NotificationFilter.transfers => event is TransferNotification,
  NotificationFilter.orders => event is OrderNotification || event is SpotOrderNotification,
};

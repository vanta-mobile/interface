import '../../../l10n/generated/app_localizations.dart';
import '../domain/account_notification.dart';
import '../../funding/presentation/transfer_record_details.dart';

String notificationTitle(AppLocalizations l10n, AccountNotification event) => switch (event) {
  TransferNotification(:final record) => transferTitle(l10n, record),
  SpotOrderNotification(:final status) => l10n.spotNotificationOrderTitle(status),
  MarginNotification() => l10n.notificationMarginTitle,
  OrderNotification(risk: OrderRisk.liquidation) => l10n.notificationLiquidationTitle,
  OrderNotification(risk: OrderRisk.adl) => l10n.notificationAdlTitle,
  OrderNotification(:final status) => l10n.notificationOrderTitle(status),
};
String notificationSide(AppLocalizations l10n, String side) => switch (side) {
  'LONG' => l10n.openOrdersLongSide,
  'SHORT' => l10n.openOrdersShortSide,
  _ => l10n.openOrdersOneWay,
};

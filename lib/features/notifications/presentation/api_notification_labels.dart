import '../../../l10n/generated/app_localizations.dart';
import '../domain/api_notification.dart';
import '../domain/notification_status.dart';

String apiNotificationTitle(AppLocalizations l, ApiNotification entry) =>
    entry.payload.title ?? l.notificationApiType(entry.type.name);
NotificationTone apiNotificationTone(ApiNotification entry) => switch (entry.severity) {
  ApiNotificationSeverity.critical => NotificationTone.negative,
  ApiNotificationSeverity.high => NotificationTone.warning,
  _ => NotificationTone.neutral,
};
String? apiNotificationMarket(AppLocalizations l, ApiNotification entry) =>
    switch (entry.payload.market) {
      'spot' => l.spot,
      'futures' || 'perp' => l.notificationPerp,
      _ => null,
    };
String? apiNotificationStatus(AppLocalizations l, ApiNotification entry) {
  final status = entry.payload.status;
  if (status == null) return null;
  return const ['processing', 'success', 'failed'].contains(status)
      ? l.assetHistoryStatus(status)
      : l.notificationStatus(status);
}

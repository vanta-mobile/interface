import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/api_notification.dart';
import '../domain/notification_status.dart';
import 'api_notification_details.dart';
import 'api_notification_labels.dart';
import 'notification_labels.dart';
import 'notification_tile.dart' show NotificationChip, NotificationStatusBadge;

class ApiNotificationTile extends StatelessWidget {
  const ApiNotificationTile(
    this.entry, {
    super.key,
    required this.ownerAddress,
    this.divider = false,
  });
  final ApiNotification entry;
  final String ownerAddress;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        market = apiNotificationMarket(AppLocalizations.of(context), entry);
    final status = apiNotificationStatus(l, entry);
    return Material(
      color: entry.read ? NotificationColors.background : NotificationColors.unread,
      child: Container(
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: NotificationColors.divider))
              : null,
        ),
        child: InkWell(
          key: ValueKey('notification-${entry.key}'),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  ApiNotificationDetails(initialEntry: entry, ownerAddress: ownerAddress),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotificationStatusBadge(switch (entry.payload.status) {
                  'FILLED' || 'success' => NotificationStatusIcon.success,
                  'REJECTED' ||
                  'CANCELED' ||
                  'EXPIRED' ||
                  'failed' => NotificationStatusIcon.failed,
                  'NEW' || 'PARTIALLY_FILLED' || 'processing' => NotificationStatusIcon.pending,
                  _ when entry.severity == ApiNotificationSeverity.critical =>
                    NotificationStatusIcon.warning,
                  _ => NotificationStatusIcon.info,
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              apiNotificationTitle(l, entry),
                              style: NotificationTypography.title,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notificationClock(entry.createdAt),
                            style: NotificationTypography.time,
                          ),
                        ],
                      ),
                      if (entry.payload.message ?? entry.symbol case final summary?)
                        Text(summary, style: NotificationTypography.body),
                      if (market != null || status != null)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (market != null) NotificationChip(market, market: true),
                            if (status != null)
                              NotificationChip(status, tone: apiNotificationTone(entry)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (!entry.read)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Semantics(
                      label: l.notificationUnread,
                      child: SvgPicture.asset(
                        'assets/portfolio/notification-unread-dot.svg',
                        key: const Key('notification-unread-dot'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

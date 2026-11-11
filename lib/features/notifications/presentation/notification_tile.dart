import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import '../domain/notification_status.dart';
import 'notification_details.dart';
import 'notification_labels.dart';

class NotificationTile extends ConsumerWidget {
  const NotificationTile(this.entry, {super.key, this.divider = true});
  final InboxEntry entry;
  final bool divider;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), event = entry.event;
    final (base, quote) = switch (event) {
      OrderNotification(:final symbol) => (
        ref.watch(notificationUnitsProvider).asData?.value[symbol]?.base,
        ref.watch(notificationUnitsProvider).asData?.value[symbol]?.quote,
      ),
      SpotOrderNotification(:final symbol) => (
        ref.watch(spotNotificationUnitsProvider).asData?.value[symbol]?.base,
        ref.watch(spotNotificationUnitsProvider).asData?.value[symbol]?.quote,
      ),
      _ => (null, null),
    };
    final tone = notificationTone(event);
    return Material(
      color: entry.read ? NotificationColors.background : NotificationColors.unread,
      child: InkWell(
        key: ValueKey('notification-${entry.key}'),
        onTap: () {
          ref.read(notificationInboxProvider.notifier).markRead(key: entry.key);
          Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => NotificationDetails(entryKey: entry.key)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: divider
                ? const Border(bottom: BorderSide(color: NotificationColors.divider))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationStatusBadge(notificationStatusIcon(event)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notificationTitle(l10n, event),
                            style: NotificationTypography.title,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notificationClock(event.eventTime),
                          style: NotificationTypography.time,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notificationSummary(l10n, event, base: base, quote: quote),
                      style: NotificationTypography.body,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        NotificationChip(notificationMarketLabel(l10n, event), market: true),
                        NotificationChip(notificationStatusLabel(l10n, event), tone: tone),
                      ],
                    ),
                  ],
                ),
              ),
              if (!entry.read) ...[
                const SizedBox(width: 10),
                Semantics(
                  label: l10n.notificationUnread,
                  child: SvgPicture.asset(
                    'assets/portfolio/notification-unread-dot.svg',
                    key: const Key('notification-unread-dot'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Design status icon in its 32 px tinted container; the SVGs carry their own colors.
class NotificationStatusBadge extends StatelessWidget {
  const NotificationStatusBadge(this.icon, {super.key});
  final NotificationStatusIcon icon;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('notification-icon-${icon.name}'),
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: switch (icon) {
        NotificationStatusIcon.info ||
        NotificationStatusIcon.pending => NotificationColors.neutralSurface,
        NotificationStatusIcon.success => NotificationColors.positiveSurface,
        NotificationStatusIcon.failed => NotificationColors.negativeSurface,
        NotificationStatusIcon.warning => NotificationColors.warningSurface,
      },
      borderRadius: BorderRadius.circular(12),
    ),
    child: SvgPicture.asset('assets/portfolio/notification-${icon.name}.svg'),
  );
}

class NotificationChip extends StatelessWidget {
  const NotificationChip(
    this.label, {
    super.key,
    this.tone = NotificationTone.neutral,
    this.market = false,
  });
  final String label;
  final NotificationTone tone;
  final bool market;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: notificationToneSurface(tone),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: NotificationTypography.chip.copyWith(
        color: market
            ? NotificationColors.title
            : tone == NotificationTone.neutral
            ? NotificationColors.muted
            : notificationToneColor(tone),
      ),
    ),
  );
}

Color notificationToneSurface(NotificationTone tone) => switch (tone) {
  NotificationTone.neutral => NotificationColors.neutralSurface,
  NotificationTone.positive => NotificationColors.positiveSurface,
  NotificationTone.warning => NotificationColors.warningSurface,
  NotificationTone.negative => NotificationColors.negativeSurface,
};

Color notificationToneColor(NotificationTone tone) => switch (tone) {
  NotificationTone.neutral => NotificationColors.neutral,
  NotificationTone.positive => NotificationColors.positive,
  NotificationTone.warning => NotificationColors.warning,
  NotificationTone.negative => NotificationColors.negative,
};

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/api_notification_provider.dart';

class NotificationInboxHeader extends ConsumerWidget {
  const NotificationInboxHeader({super.key, required this.unread});
  final int unread;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final marking = ref.watch(apiNotificationInboxProvider.select((s) => s.marking));
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 7, 4, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            IconButton(
              key: const Key('notification-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 44),
                padding: EdgeInsets.zero,
              ),
              icon: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: PortfolioIcon('back.svg', size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.notificationTitle,
                      style: NotificationTypography.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label: l10n.notificationUnreadCount(unread),
                      excludeSemantics: true,
                      child: Container(
                        key: const Key('notification-unread-count'),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: NotificationColors.neutralSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$unread',
                          style: NotificationTypography.chip.copyWith(
                            color: NotificationColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread > 0)
              Flexible(
                // Keep unused flex space to the left so the action stays flush right.
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('notification-read-all'),
                    onPressed: marking
                        ? null
                        : () => ref.read(apiNotificationInboxProvider.notifier).markRead(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: marking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.notificationMarkAllRead,
                            style: NotificationTypography.action,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

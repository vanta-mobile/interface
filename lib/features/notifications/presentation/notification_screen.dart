import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/application/transfer_history_load_provider.dart';
import '../../funding/application/transfer_history_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import '../domain/notification_status.dart';
import 'notification_labels.dart';
import 'notification_tile.dart';

void openNotifications(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const NotificationScreen()));

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  NotificationFilter _filter = NotificationFilter.all;
  bool _unreadOnly = false;

  /// Settles only after storage, transfer status and market units have all finished.
  Future<void> _refresh() async {
    Future<void> settle(Future<void> Function() task) => task().catchError((Object _) {});
    await Future.wait([
      settle(ref.read(notificationInboxProvider.notifier).retry),
      if (ref.read(authProvider).identity?.walletAddress != null)
        settle(ref.read(transferHistoryProvider.notifier).refresh),
      settle(() {
        ref.invalidate(notificationUnitsProvider);
        return ref.read(notificationUnitsProvider.future);
      }),
      settle(() {
        ref.invalidate(spotNotificationUnitsProvider);
        return ref.read(spotNotificationUnitsProvider.future);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transferHistoryLoadProvider);
    final entries = ref.watch(walletNotificationsProvider);
    final unread = entries.where((e) => !e.read).length;
    return Scaffold(
      backgroundColor: NotificationColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NotificationHeader(unread: unread),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _NotificationTabs(
                    selected: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: _NotificationList(
                      entries: [
                        for (final entry in entries)
                          if (notificationMatches(_filter, entry.event) &&
                              (!_unreadOnly || !entry.read))
                            entry,
                      ],
                      unreadOnly: _unreadOnly,
                      onUnreadOnly: (value) => setState(() => _unreadOnly = value),
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

class _NotificationHeader extends ConsumerWidget {
  const _NotificationHeader({required this.unread});
  final int unread;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
                    onPressed: () => ref.read(notificationInboxProvider.notifier).markRead(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
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

class _NotificationTabs extends StatelessWidget {
  const _NotificationTabs({required this.selected, required this.onChanged});
  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NotificationColors.neutralSurface)),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in NotificationFilter.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 20),
                  child: Semantics(
                    button: true,
                    selected: filter == selected,
                    child: InkWell(
                      key: Key('notification-filter-${filter.name}'),
                      onTap: () => onChanged(filter),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44),
                        child: IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 17),
                              Text(
                                switch (filter) {
                                  NotificationFilter.all => l10n.notificationFilterAll,
                                  NotificationFilter.transfers => l10n.notificationFilterTransfers,
                                  NotificationFilter.orders => l10n.notificationFilterOrders,
                                },
                                style: NotificationTypography.tab.copyWith(
                                  color: filter == selected
                                      ? PortfolioColors.text
                                      : NotificationColors.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 1,
                                color: filter == selected
                                    ? NotificationColors.accent
                                    : PortfolioColors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({
    required this.entries,
    required this.unreadOnly,
    required this.onUnreadOnly,
  });
  final List<InboxEntry> entries;
  final bool unreadOnly;
  final ValueChanged<bool> onUnreadOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final inbox = ref.watch(notificationInboxProvider);
    final signedIn = auth.identity?.walletAddress != null;
    final groups = <DateTime, List<InboxEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(notificationDay(entry.event.eventTime), () => []).add(entry);
    }
    final now = DateTime.now();
    return ListView(
      key: const Key('notification-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _UnreadOnlyToggle(value: unreadOnly, onChanged: onUnreadOnly),
        if (inbox.storageFailed)
          StatusFailureView(
            message: l10n.notificationStorageFailed,
            retryKey: const Key('notification-retry'),
            onRetry: ref.read(notificationInboxProvider.notifier).retry,
          ),
        if (!signedIn)
          StatusEmptyView(
            message: l10n.notificationSignIn,
            actionKey: const Key('notification-sign-in'),
            actionLabel: l10n.accountSignInToRead,
            onAction: auth.busy ? null : () => showAccountSheet(context),
          )
        else if (!inbox.loaded && !inbox.storageFailed && entries.isEmpty)
          const _NotificationSkeleton()
        else if (inbox.loaded && entries.isEmpty)
          StatusEmptyView(key: const Key('notification-empty'), message: l10n.notificationEmpty)
        else
          for (final group in groups.entries) ...[
            Text(notificationDayLabel(l10n, group.key, now), style: NotificationTypography.group),
            const SizedBox(height: 8),
            for (final (index, entry) in group.value.indexed)
              NotificationTile(entry, divider: index < group.value.length - 1),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _UnreadOnlyToggle extends StatelessWidget {
  const _UnreadOnlyToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Semantics(
      checked: value,
      child: InkWell(
        key: const Key('notification-unread-only'),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: value ? NotificationColors.accent : NotificationColors.title,
                    width: .7,
                  ),
                  borderRadius: BorderRadius.circular(5.6),
                ),
                child: value
                    ? const Icon(Icons.check_rounded, size: 10, color: NotificationColors.accent)
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).notificationUnreadOnly,
                  style: NotificationTypography.filter,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('notification-skeleton'),
    children: [
      for (var i = 0; i < 4; i++)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 32, height: 32, radius: 12),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16),
                    SizedBox(height: 4),
                    SkeletonBox(height: 16),
                    SizedBox(height: 4),
                    SkeletonBox(width: 96, height: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

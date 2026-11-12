import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/api_notification_provider.dart';
import '../application/notification_refresh_provider.dart';
import 'push_visibility_notice.dart';
import '../domain/api_notification.dart';
import '../domain/notification_status.dart';
import 'notification_labels.dart';
import 'api_notification_tile.dart';
import 'notification_api_error.dart';
import 'notification_inbox_header.dart';

void openNotifications(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const NotificationScreen()));

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(notificationPageRefreshProvider)());
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(apiNotificationInboxProvider);
    final entries = inbox.items;
    final unread = inbox.unread;
    final filter = inbox.category;
    final unreadOnly = inbox.unreadOnly;
    return Scaffold(
      backgroundColor: NotificationColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NotificationInboxHeader(unread: unread),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _NotificationTabs(
                    selected: filter,
                    onChanged: (value) =>
                        ref.read(apiNotificationInboxProvider.notifier).filter(value, unreadOnly),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: ref.read(notificationPageRefreshProvider),
                    child: _NotificationList(
                      entries: entries,
                      unreadOnly: unreadOnly,
                      onUnreadOnly: (value) =>
                          ref.read(apiNotificationInboxProvider.notifier).filter(filter, value),
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
  final List<ApiNotification> entries;
  final bool unreadOnly;
  final ValueChanged<bool> onUnreadOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final inbox = ref.watch(apiNotificationInboxProvider);
    final signedIn = auth.identity?.walletAddress != null;
    final groups = <DateTime, List<ApiNotification>>{};
    for (final entry in entries) {
      groups.putIfAbsent(notificationDay(entry.createdAt), () => []).add(entry);
    }
    final now = DateTime.now();
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (event.metrics.extentAfter < 200 &&
            inbox.nextCursor != null &&
            !inbox.loading &&
            inbox.error == null) {
          unawaited(ref.read(apiNotificationInboxProvider.notifier).loadMore());
        }
        return false;
      },
      child: ListView(
        key: const Key('notification-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _UnreadOnlyToggle(value: unreadOnly, onChanged: onUnreadOnly),
          const PushVisibilityNotice(),
          if (inbox.error != null)
            StatusFailureView(
              message: notificationApiErrorText(context, inbox.error!),
              retryKey: const Key('notification-retry'),
              retrying: inbox.loading,
              onRetry: inbox.loading
                  ? null
                  : ref.read(apiNotificationInboxProvider.notifier).refresh,
            ),
          if (!signedIn)
            StatusEmptyView(
              message: l10n.notificationSignIn,
              actionKey: const Key('notification-sign-in'),
              actionLabel: l10n.accountSignInToRead,
              onAction: auth.busy ? null : () => showAccountSheet(context),
            )
          else if (!ref.watch(vantaApiSessionProvider).ready)
            const NotificationApiAccess()
          else if (!inbox.loaded && inbox.loading && entries.isEmpty)
            const _NotificationSkeleton()
          else if (inbox.loaded && entries.isEmpty)
            StatusEmptyView(key: const Key('notification-empty'), message: l10n.notificationEmpty)
          else
            for (final group in groups.entries) ...[
              Text(notificationDayLabel(l10n, group.key, now), style: NotificationTypography.group),
              const SizedBox(height: 8),
              for (final (index, entry) in group.value.indexed)
                ApiNotificationTile(
                  entry,
                  ownerAddress: auth.identity!.walletAddress!.toLowerCase(),
                  divider: index < group.value.length - 1,
                ),
              const SizedBox(height: 8),
            ],
          if (inbox.loading && entries.isNotEmpty) const Center(child: CircularProgressIndicator()),
        ],
      ),
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

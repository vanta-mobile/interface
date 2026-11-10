import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/presentation/transfer_history_screen.dart';
import '../../funding/presentation/transfer_record_details.dart';
import '../../portfolio/presentation/account_change_panel.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import 'notification_details.dart';
import 'notification_labels.dart';
import '../../../core/presentation/status_view.dart';

void openNotifications(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const NotificationScreen()));

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final inbox = ref.watch(notificationInboxProvider);
    final entries = ref.watch(walletNotificationsProvider);
    final address = auth.identity?.walletAddress;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('notification-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.notificationScope),
            if (address != null) SelectableText(address),
            Text(l10n.notificationDelivery),
            Text(l10n.notificationRetention, style: Theme.of(context).textTheme.bodySmall),
            const AccountChangePanel(),
            const AccountChangePanel(spot: true),
            const TransferHistoryEntry(),
            if (!inbox.loaded && !inbox.storageFailed) const LinearProgressIndicator(),
            if (inbox.storageFailed) ...[
              Text(
                l10n.notificationStorageFailed,
                style: const TextStyle(color: AppColors.negative),
              ),
              OutlinedButton(
                key: const Key('notification-retry'),
                onPressed: ref.read(notificationInboxProvider.notifier).retry,
                child: Text(l10n.notificationRetry),
              ),
            ],
            if (address == null) ...[
              Text(l10n.notificationSignIn),
              OutlinedButton(
                onPressed: auth.busy ? null : () => showAccountSheet(context),
                child: Text(l10n.accountSignInToRead),
              ),
            ] else ...[
              if (entries.any((e) => !e.read))
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('notification-read-all'),
                    onPressed: () => ref.read(notificationInboxProvider.notifier).markRead(),
                    child: Text(l10n.notificationMarkAllRead),
                  ),
                ),
              if (inbox.loaded && entries.isEmpty)
                StatusEmptyView(
                  key: const Key('notification-empty'),
                  message: l10n.notificationEmpty,
                ),
              for (final entry in entries) _NotificationCard(entry),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard(this.entry);
  final InboxEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), event = entry.event;
    final base = event is OrderNotification
        ? ref.watch(notificationUnitsProvider).asData?.value[event.symbol]?.base
        : event is SpotOrderNotification
        ? ref.watch(spotNotificationUnitsProvider).asData?.value[event.symbol]?.base
        : null;
    return Card(
      child: InkWell(
        key: ValueKey('notification-${entry.key}'),
        onTap: () {
          ref.read(notificationInboxProvider.notifier).markRead(key: entry.key);
          Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => NotificationDetails(entryKey: entry.key)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(notificationTitle(l10n, event), style: Theme.of(context).textTheme.titleMedium),
              if (event.critical)
                Text(l10n.notificationCritical, style: const TextStyle(color: AppColors.negative)),
              Text(
                entry.read ? l10n.notificationRead : l10n.notificationUnread,
                style: TextStyle(color: entry.read ? AppColors.secondary : AppColors.accent),
              ),
              if (event is OrderNotification) ...[
                Text(
                  '${event.symbol} · ${event.side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell}',
                ),
                Text(l10n.notificationStatus(event.status)),
                Text(
                  '${l10n.notificationLastQuantity}: ${event.lastQuantity} ${base ?? l10n.accountUnitUnavailable}',
                ),
                Text(
                  '${l10n.notificationCumulativeQuantity}: ${event.filledQuantity} ${base ?? l10n.accountUnitUnavailable}',
                ),
              ] else if (event is SpotOrderNotification) ...[
                Text(
                  '${event.symbol} · ${event.side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell}',
                ),
                Text(l10n.notificationStatus(event.status)),
                Text(
                  '${l10n.notificationLastQuantity}: ${event.lastQuantity} ${base ?? l10n.accountUnitUnavailable}',
                ),
                Text(
                  '${l10n.notificationCumulativeQuantity}: ${event.filledQuantity} ${base ?? l10n.accountUnitUnavailable}',
                ),
              ] else if (event is TransferNotification) ...[
                Text('${event.record.amount} ${event.record.asset}'),
                Text(transferMarketLabel(l10n, event.record.market)),
                Text(transferNetworkLabel(l10n, event.record.chainId)),
              ] else if (event is MarginNotification)
                Text(event.positions.map((p) => p.symbol).join(', ')),
              Text(event.eventTime.toIso8601String()),
            ],
          ),
        ),
      ),
    );
  }
}

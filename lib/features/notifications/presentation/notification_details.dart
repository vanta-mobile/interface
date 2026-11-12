import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/presentation/transfer_record_screen.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import 'balance_notification_details.dart';
import 'margin_notification_details.dart';
import 'notification_detail_components.dart';
import 'notification_units_status.dart';
import 'order_notification_details.dart';
import 'spot_notification_details.dart';

/// Resolve facts against the current wallet, including when this route is already open.
class NotificationDetails extends ConsumerStatefulWidget {
  const NotificationDetails({super.key, required this.entryKey});
  final String entryKey;
  @override
  ConsumerState<NotificationDetails> createState() => _NotificationDetailsState();
}

class _NotificationDetailsState extends ConsumerState<NotificationDetails> {
  bool _readScheduled = false;

  void _markOnEntry(InboxEntry entry) {
    if (entry.read || _readScheduled) return;
    _readScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readScheduled = false;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final current = ref
          .read(walletNotificationsProvider)
          .where((e) => e.key == widget.entryKey)
          .firstOrNull;
      if (current != null && !current.read) {
        unawaited(ref.read(notificationInboxProvider.notifier).markRead(key: current.key));
      }
    });
  }

  Future<void> _refresh(AccountNotification? event) async {
    Future<void> settle(Future<void> Function() task) => task().catchError((Object _) {});
    await Future.wait([
      settle(ref.read(notificationInboxProvider.notifier).retry),
      if (event is SpotOrderNotification)
        settle(() async {
          ref.invalidate(spotNotificationUnitsProvider);
          await ref.read(spotNotificationUnitsProvider.future);
        })
      else if (event is OrderNotification || event is MarginNotification)
        settle(() async {
          ref.invalidate(notificationUnitsProvider);
          await ref.read(notificationUnitsProvider.future);
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entry = ref
        .watch(walletNotificationsProvider)
        .where((e) => e.key == widget.entryKey)
        .firstOrNull;
    if (entry != null) _markOnEntry(entry);
    final event = entry?.event;
    // The design explicitly reuses the Portfolio transaction detail page.
    if (event is TransferNotification) {
      return TransferRecordScreen(
        recordKey: event.record.key,
        ownerAddress: entry!.address,
        initialRecord: event.record,
      );
    }
    return Scaffold(
      backgroundColor: NotificationColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NotificationDetailHeader(title: l.notificationDetailsTitle),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refresh(event),
                    child: SingleChildScrollView(
                      key: const Key('notification-details'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (event == null) StatusEmptyView(message: l.notificationEmpty),
                          if (event is OrderNotification) OrderNotificationDetails(event),
                          if (event is SpotOrderNotification) SpotNotificationDetails(event),
                          if (event is MarginNotification) MarginNotificationDetails(event),
                          if (event is BalanceNotification) BalanceNotificationDetails(event),
                          if (event is OrderNotification || event is MarginNotification)
                            const NotificationUnitsStatus(),
                          if (event is SpotOrderNotification)
                            const NotificationUnitsStatus(spot: true),
                          if (ref.watch(notificationInboxProvider).storageFailed)
                            StatusFailureView(
                              message: l.notificationStorageFailed,
                              onRetry: ref.read(notificationInboxProvider.notifier).retry,
                            ),
                        ],
                      ),
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

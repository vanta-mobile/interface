import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../application/api_notification_provider.dart';
import '../domain/api_notification.dart';
import 'api_notification_labels.dart';
import 'notification_api_error.dart';
import 'notification_detail_components.dart';

class ApiNotificationDetails extends ConsumerStatefulWidget {
  const ApiNotificationDetails({super.key, required this.initialEntry, required this.ownerAddress});
  final ApiNotification initialEntry;
  final String ownerAddress;
  @override
  ConsumerState<ApiNotificationDetails> createState() => _ApiNotificationDetailsState();
}

class _ApiNotificationDetailsState extends ConsumerState<ApiNotificationDetails> {
  bool _entered = false;
  ApiNotification? _entry() {
    final session = ref.read(vantaApiSessionProvider);
    if (!session.ready ||
        session.address != widget.ownerAddress ||
        ref.read(authProvider).identity?.walletAddress?.toLowerCase() != widget.ownerAddress) {
      return null;
    }
    return ref.read(apiNotificationInboxProvider).cache[widget.initialEntry.key] ??
        widget.initialEntry;
  }

  Future<void> _refresh() async {
    final entry = _entry();
    if (entry == null) return;
    final controller = ref.read(apiNotificationInboxProvider.notifier);
    if (!entry.read) {
      await controller.markRead(entry);
    } else {
      await controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    ref.watch(vantaApiSessionProvider);
    final inbox = ref.watch(apiNotificationInboxProvider), entry = _entry();
    if (!_entered && entry != null) {
      _entered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        final current = _entry();
        if (current != null && !current.read) {
          unawaited(ref.read(apiNotificationInboxProvider.notifier).markRead(current));
        }
      });
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
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      key: const Key('notification-details'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: [
                          if (entry == null)
                            StatusEmptyView(message: l.notificationEmpty)
                          else
                            ApiNotificationFacts(entry),
                          if (entry != null && inbox.error != null)
                            StatusFailureView(
                              message: notificationApiErrorText(context, inbox.error!),
                              retrying: inbox.marking || inbox.loading,
                              onRetry: inbox.marking || inbox.loading ? null : _refresh,
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

/// Uses the same cards, type scale and copy controls as the supplied detail
/// design. Sparse API payloads display only facts the backend actually supplies.
class ApiNotificationFacts extends StatelessWidget {
  const ApiNotificationFacts(this.entry, {super.key});
  final ApiNotification entry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = entry.payload;
    final market = apiNotificationMarket(l, entry);
    final amount = p.numbers[NotificationNumber.amount];
    String number(NotificationNumber key) {
      final unit = switch (key) {
        NotificationNumber.quantity => p.baseAsset,
        NotificationNumber.fee => p.feeAsset,
        NotificationNumber.amount => p.asset,
        _ => p.quoteAsset,
      };
      // The contract does not define distance units. Never turn it into a %.
      if (key == NotificationNumber.distance) return '${p.numbers[key]}';
      return notificationAmount(p.numbers[key]!, unit, l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        NotificationDetailSummary(
          title: apiNotificationTitle(l, entry),
          value: amount == null
              ? entry.symbol ?? l.notificationApiType(entry.type.name)
              : number(NotificationNumber.amount),
          status: apiNotificationStatus(l, entry),
          tone: apiNotificationTone(entry),
        ),
        if (p.message != null)
          NotificationDetailCard(
            children: [SelectableText(p.message!, style: NotificationTypography.detailValue)],
          ),
        NotificationDetailCard(
          children: [
            NotificationDetailRow(
              l.notificationApiField('createdAt'),
              DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.createdAt.toLocal()),
            ),
            if (entry.symbol != null)
              NotificationDetailRow(l.notificationApiField('symbol'), entry.symbol!),
            if (market != null) NotificationDetailRow(l.notificationApiField('market'), market),
            if (p.side != null)
              NotificationDetailRow(
                l.notificationApiField('side'),
                l.notificationOrderSide(p.side!),
              ),
            for (final key in p.numbers.keys)
              NotificationDetailRow(l.notificationApiField(key.name), number(key)),
            if (p.orderId != null)
              NotificationDetailRow(l.notificationApiField('orderId'), p.orderId!, copyable: true),
            if (p.transactionHash != null)
              NotificationDetailRow(
                l.notificationApiField('transactionHash'),
                p.transactionHash!,
                copyable: true,
              ),
            NotificationDetailRow(l.notificationApiField('eventKey'), entry.key, copyable: true),
          ],
        ),
      ],
    );
  }
}

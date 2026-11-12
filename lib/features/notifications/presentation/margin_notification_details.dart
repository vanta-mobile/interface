import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/presentation/transfer_history_components.dart' show historyTime;
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import '../domain/notification_status.dart';
import 'notification_detail_components.dart';
import 'notification_labels.dart';

class MarginNotificationDetails extends ConsumerWidget {
  const MarginNotificationDetails(this.event, {super.key});
  final MarginNotification event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), e = event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        NotificationDetailSummary(
          title: l.notificationMarginTitle,
          value: e.positions.map((p) => p.symbol).toSet().join(', '),
          status: l.notificationCritical,
          tone: NotificationTone.warning,
        ),
        NotificationDetailCard(
          children: [
            NotificationDetailRow(l.notificationEventTime, historyTime(e.eventTime)),
            if (e.crossWalletBalance != null)
              NotificationDetailRow(
                l.accountCrossWalletBalance,
                notificationAmount(e.crossWalletBalance!, null, l),
              ),
          ],
        ),
        NotificationDetailSection(l.notificationAffectedPositions),
        for (final position in e.positions) _Position(position),
        Text(l.notificationMarginScope, style: NotificationTypography.detailLabel),
      ],
    );
  }
}

class _Position extends ConsumerWidget {
  const _Position(this.position);
  final MarginRiskPosition position;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), p = position;
    final units = ref.watch(notificationUnitsProvider).asData?.value[p.symbol];
    String amount(Decimal v, String? unit) => notificationAmount(v, unit, l);
    return NotificationDetailCard(
      spacing: 14,
      children: [
        SelectableText(p.symbol, style: NotificationTypography.detailSection),
        NotificationDetailRow(l.notificationPositionSide, notificationSide(l, p.side)),
        NotificationDetailRow(l.quantity, amount(p.quantity, units?.base)),
        NotificationDetailRow(
          l.accountMarginMode,
          p.marginType == 'CROSSED' ? l.cross : l.accountIsolatedMode,
        ),
        if (p.marginType == 'ISOLATED' && p.isolatedWallet != null)
          NotificationDetailRow(
            l.positionRiskIsolatedWallet,
            amount(p.isolatedWallet!, units?.margin),
          ),
        NotificationDetailRow(l.openOrdersMarkPrice, amount(p.markPrice, units?.quote)),
        NotificationDetailRow(
          l.accountUnrealizedPnl,
          amount(p.unrealizedPnl, units?.margin),
          color: notificationPnlColor(p.unrealizedPnl),
        ),
        NotificationDetailRow(
          l.notificationMaintenanceMargin,
          amount(p.maintenanceMargin, units?.margin),
        ),
      ],
    );
  }
}

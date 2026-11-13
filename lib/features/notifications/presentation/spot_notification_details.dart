import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../funding/presentation/transfer_history_components.dart' show historyTime;
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import '../domain/notification_status.dart';
import 'notification_detail_components.dart';

class SpotNotificationDetails extends ConsumerWidget {
  const SpotNotificationDetails(this.event, {super.key});
  final SpotOrderNotification event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), e = event;
    final units = ref.watch(spotNotificationUnitsProvider).asData?.value[e.symbol];
    String base(Decimal v) => notificationAmount(v, units?.base, l);
    String quote(Decimal v) => notificationAmount(v, units?.quote, l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        NotificationDetailSummary(
          title: e.side == 'BUY' ? l.spotSideBuy : l.spotSideSell,
          value: base(e.quantity),
          status: l.notificationStatus(e.status),
          tone: notificationTone(e),
        ),
        NotificationDetailSection(l.tradingHistoryOrderDetails),
        NotificationDetailCard(
          children: [
            NotificationDetailRow(l.notificationEventTime, historyTime(e.eventTime)),
            NotificationDetailRow(l.notificationTradeTime, historyTime(e.transactionTime)),
            NotificationDetailRow(
              l.spotNotificationCreationTime,
              e.creationMilliseconds != null && e.creationMilliseconds! > 0
                  ? historyTime(
                      DateTime.fromMillisecondsSinceEpoch(e.creationMilliseconds!, isUtc: true),
                    )
                  : l.openOrdersCreationUnknown,
            ),
            NotificationDetailRow(l.orderId, e.orderId, copyable: true),
            NotificationDetailRow(l.liveOrderClientId, e.clientOrderId, copyable: true),
            NotificationDetailRow(l.openOrdersOrderType, l.notificationOrderType(e.orderType)),
            NotificationDetailRow(
              l.notificationExecutionType,
              l.notificationExecution(e.executionType),
            ),
            NotificationDetailRow(l.openOrdersStatus, l.notificationStatus(e.status)),
            NotificationDetailRow(l.notificationOriginalQuantity, base(e.quantity)),
            NotificationDetailRow(l.openOrdersOrderPrice, quote(e.price)),
          ],
        ),
        NotificationDetailSection(l.notificationExecutionDetails),
        NotificationDetailCard(
          children: [
            NotificationDetailRow(l.notificationLastQuantity, base(e.lastQuantity)),
            NotificationDetailRow(l.notificationCumulativeQuantity, base(e.filledQuantity)),
            NotificationDetailRow(l.notificationLastPrice, quote(e.lastPrice)),
            NotificationDetailRow(l.historyAveragePrice, quote(e.averagePrice)),
            NotificationDetailRow(l.spotNotificationLastQuote, quote(e.lastQuoteAmount)),
            NotificationDetailRow(
              l.spotNotificationCumulativeQuote,
              quote(e.cumulativeQuoteAmount),
            ),
            NotificationDetailRow(l.historyTradeId, e.tradeId, copyable: true),
            if (e.fee != null)
              NotificationDetailRow(l.historyCommission, notificationAmount(e.fee!, e.feeAsset, l)),
          ],
        ),
      ],
    );
  }
}

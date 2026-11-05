import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import 'notification_field.dart';

class SpotNotificationDetails extends ConsumerWidget {
  const SpotNotificationDetails(this.event, {super.key});
  final SpotOrderNotification event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), e = event;
    final units = ref.watch(spotNotificationUnitsProvider).asData?.value[e.symbol];
    String base(Decimal value) => '$value ${units?.base ?? l10n.accountUnitUnavailable}';
    String quote(Decimal value) => '$value ${units?.quote ?? l10n.accountUnitUnavailable}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.spot),
        NotificationField(l10n.marketDetails, e.symbol),
        NotificationField(l10n.orderId, e.orderId),
        NotificationField(l10n.liveOrderClientId, e.clientOrderId),
        NotificationField(
          l10n.accountPositionDirection,
          e.side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell,
        ),
        NotificationField(l10n.openOrdersStatus, l10n.notificationStatus(e.status)),
        Text(l10n.notificationExecution(e.executionType)),
        NotificationField(l10n.openOrdersOrderType, l10n.notificationOrderType(e.orderType)),
        if (e.originalType != null)
          NotificationField(
            l10n.notificationOriginalType,
            l10n.notificationOrderType(e.originalType!),
          ),
        NotificationField(l10n.notificationOriginalQuantity, base(e.quantity)),
        NotificationField(l10n.notificationLastQuantity, base(e.lastQuantity)),
        NotificationField(l10n.notificationCumulativeQuantity, base(e.filledQuantity)),
        NotificationField(l10n.openOrdersOrderPrice, quote(e.price)),
        NotificationField(l10n.notificationLastPrice, quote(e.lastPrice)),
        NotificationField(l10n.historyAveragePrice, quote(e.averagePrice)),
        NotificationField(l10n.spotNotificationLastQuote, quote(e.lastQuoteAmount)),
        NotificationField(l10n.spotNotificationCumulativeQuote, quote(e.cumulativeQuoteAmount)),
        if (e.quoteOrderQuantity != null)
          NotificationField(l10n.spotNotificationQuoteOrderQuantity, quote(e.quoteOrderQuantity!)),
        if (e.stopPrice != null)
          NotificationField(l10n.openOrdersTriggerPrice, quote(e.stopPrice!)),
        NotificationField(l10n.historyTradeId, e.tradeId),
        if (e.fee != null) NotificationField(l10n.historyCommission, '${e.fee} ${e.feeAsset}'),
        NotificationField(l10n.notificationTransactionTime, e.transactionTime.toIso8601String()),
        NotificationField(
          l10n.spotNotificationCreationTime,
          e.creationMilliseconds != null && e.creationMilliseconds! > 0
              ? DateTime.fromMillisecondsSinceEpoch(
                  e.creationMilliseconds!,
                  isUtc: true,
                ).toIso8601String()
              : l10n.openOrdersCreationUnknown,
        ),
      ],
    );
  }
}

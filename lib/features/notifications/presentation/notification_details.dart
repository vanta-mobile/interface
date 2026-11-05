import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/domain/aster_account.dart';
import '../../funding/presentation/transfer_record_details.dart';
import '../application/notification_provider.dart';
import '../domain/account_notification.dart';
import 'notification_labels.dart';
import 'notification_field.dart';
import 'notification_units_status.dart';
import 'spot_notification_details.dart';

/// Resolves by current wallet on every rebuild, including an already-open route.
class NotificationDetails extends ConsumerWidget {
  const NotificationDetails({super.key, required this.entryKey});
  final String entryKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    InboxEntry? entry;
    for (final candidate in ref.watch(walletNotificationsProvider)) {
      if (candidate.key == entryKey) entry = candidate;
    }
    final event = entry?.event;
    return Scaffold(
      appBar: AppBar(
        title: Text(event == null ? l10n.notificationTitle : notificationTitle(l10n, event)),
      ),
      body: SafeArea(
        child: event == null
            ? Padding(padding: const EdgeInsets.all(16), child: Text(l10n.notificationEmpty))
            : ListView(
                key: const Key('notification-details'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (event is! TransferNotification) ...[
                    Text(l10n.notificationUnits),
                    NotificationUnitsStatus(spot: event is SpotOrderNotification),
                  ],
                  NotificationField(
                    event is TransferNotification
                        ? l10n.transferObservedTime
                        : l10n.notificationEventTime,
                    event.eventTime.toIso8601String(),
                  ),
                  if (event is OrderNotification) _OrderDetails(event),
                  if (event is SpotOrderNotification) SpotNotificationDetails(event),
                  if (event is TransferNotification) TransferRecordDetails(event.record),
                  if (event is MarginNotification) ...[
                    Text(l10n.notificationMarginScope),
                    if (event.crossWalletBalance != null)
                      NotificationField(
                        l10n.accountCrossWalletBalance,
                        '${event.crossWalletBalance} ${l10n.accountUnitUnavailable}',
                      ),
                    for (final position in event.positions) _MarginDetails(position),
                  ],
                ],
              ),
      ),
    );
  }
}

class _OrderDetails extends ConsumerWidget {
  const _OrderDetails(this.event);
  final OrderNotification event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), e = event;
    final units = ref.watch(notificationUnitsProvider).asData?.value[e.symbol];
    String base(Decimal value) => '$value ${units?.base ?? l10n.accountUnitUnavailable}';
    String quote(Decimal value) => '$value ${units?.quote ?? l10n.accountUnitUnavailable}';
    String margin(Decimal value) => '$value ${units?.margin ?? l10n.accountUnitUnavailable}';
    String yesNo(bool value) => value ? l10n.notificationYes : l10n.notificationNo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.critical) Text(l10n.notificationRiskScope),
        NotificationField(l10n.marketDetails, e.symbol),
        NotificationField(l10n.orderId, e.orderId),
        NotificationField(l10n.liveOrderClientId, e.clientOrderId),
        NotificationField(
          l10n.accountPositionDirection,
          '${e.side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell} · ${notificationSide(l10n, e.positionSide)}',
        ),
        NotificationField(l10n.openOrdersStatus, l10n.notificationStatus(e.status)),
        Text(l10n.notificationExecution(e.executionType)),
        NotificationField(l10n.openOrdersOrderType, l10n.notificationOrderType(e.orderType)),
        NotificationField(
          l10n.notificationOriginalType,
          l10n.notificationOrderType(e.originalType),
        ),
        NotificationField(l10n.notificationOriginalQuantity, base(e.quantity)),
        NotificationField(l10n.notificationLastQuantity, base(e.lastQuantity)),
        NotificationField(l10n.notificationCumulativeQuantity, base(e.filledQuantity)),
        NotificationField(l10n.openOrdersOrderPrice, quote(e.price)),
        NotificationField(l10n.notificationLastPrice, quote(e.lastPrice)),
        NotificationField(l10n.historyAveragePrice, quote(e.averagePrice)),
        NotificationField(l10n.historyTradeId, e.tradeId),
        if (e.fee != null) NotificationField(l10n.historyCommission, '${e.fee} ${e.feeAsset}'),
        NotificationField(l10n.notificationRealizedPnl, margin(e.realizedPnl)),
        if (e.triggerPrice != null)
          NotificationField(l10n.openOrdersTriggerPrice, quote(e.triggerPrice!)),
        if (e.workingType != null)
          Text(e.workingType == 'MARK_PRICE' ? l10n.openOrdersMarkPrice : l10n.openOrdersLastPrice),
        NotificationField(l10n.openOrdersReduceOnly, yesNo(e.reduceOnly)),
        if (e.closePosition != null)
          NotificationField(l10n.openOrdersClosePosition, yesNo(e.closePosition!)),
        NotificationField(l10n.notificationTransactionTime, e.transactionTime.toIso8601String()),
        NotificationField(l10n.notificationTradeTime, e.tradeTime.toIso8601String()),
      ],
    );
  }
}

class _MarginDetails extends ConsumerWidget {
  const _MarginDetails(this.position);
  final MarginRiskPosition position;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), p = position;
    final AsterContractUnits? units = ref.watch(notificationUnitsProvider).asData?.value[p.symbol];
    String amount(Decimal value, String? unit) => '$value ${unit ?? l10n.accountUnitUnavailable}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(p.symbol, style: Theme.of(context).textTheme.titleMedium),
            Text(notificationSide(l10n, p.side)),
            NotificationField(l10n.quantity, amount(p.quantity, units?.base)),
            NotificationField(
              l10n.accountMarginMode,
              p.marginType == 'CROSSED' ? l10n.cross : l10n.accountIsolatedMode,
            ),
            if (p.isolatedWallet != null)
              NotificationField(
                l10n.positionRiskIsolatedWallet,
                amount(p.isolatedWallet!, units?.margin),
              ),
            NotificationField(l10n.openOrdersMarkPrice, amount(p.markPrice, units?.quote)),
            NotificationField(l10n.accountUnrealizedPnl, amount(p.unrealizedPnl, units?.margin)),
            NotificationField(
              l10n.notificationMaintenanceMargin,
              amount(p.maintenanceMargin, units?.margin),
            ),
          ],
        ),
      ),
    );
  }
}

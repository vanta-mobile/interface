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

class OrderNotificationDetails extends ConsumerWidget {
  const OrderNotificationDetails(this.event, {super.key});
  final OrderNotification event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), e = event;
    final units = ref.watch(notificationUnitsProvider).asData?.value[e.symbol];
    String base(Decimal v) => notificationAmount(v, units?.base, l);
    String quote(Decimal v) => notificationAmount(v, units?.quote, l);
    String margin(Decimal v) => notificationAmount(v, units?.margin, l);
    final risk = e.risk != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        NotificationDetailSummary(
          title: notificationTitle(l, e),
          value: risk ? e.symbol : '${e.lastQuantity} ${e.symbol}',
          status: risk ? l.notificationCritical : l.notificationStatus(e.status),
          tone: risk ? NotificationTone.warning : notificationTone(e),
        ),
        NotificationDetailSection(
          risk ? l.notificationRiskOrderDetails : l.tradingHistoryOrderDetails,
        ),
        NotificationDetailCard(
          children: risk ? _riskRows(e, l, base, quote, margin) : _parameterRows(e, l, quote),
        ),
        if (!risk) ...[
          NotificationDetailSection(l.notificationExecutionDetails),
          NotificationDetailCard(children: _executionRows(e, l, base, quote, margin)),
        ],
        if (risk) Text(l.notificationRiskScope, style: NotificationTypography.detailLabel),
      ],
    );
  }
}

typedef _Amount = String Function(Decimal);

List<Widget> _riskRows(
  OrderNotification e,
  AppLocalizations l,
  _Amount base,
  _Amount quote,
  _Amount margin,
) => [
  NotificationDetailRow(
    l.notificationRiskType,
    e.risk == OrderRisk.adl ? l.notificationAdlChip : l.notificationRiskLiquidation,
  ),
  NotificationDetailRow(l.marketDetails, e.symbol),
  NotificationDetailRow(l.assetHistoryTime, historyTime(e.eventTime)),
  NotificationDetailRow(l.orderId, e.orderId, copyable: true),
  NotificationDetailRow(l.notificationPositionSide, notificationSide(l, e.positionSide)),
  NotificationDetailRow(l.notificationExecutionType, l.notificationExecution(e.executionType)),
  NotificationDetailRow(l.openOrdersStatus, l.notificationStatus(e.status)),
  NotificationDetailRow(l.notificationCumulativeQuantity, base(e.filledQuantity)),
  NotificationDetailRow(l.historyAveragePrice, quote(e.averagePrice)),
  NotificationDetailRow(
    l.notificationRealizedPnl,
    margin(e.realizedPnl),
    color: notificationPnlColor(e.realizedPnl),
  ),
  NotificationDetailRow(l.historyTradeId, e.tradeId, copyable: true),
];

List<Widget> _parameterRows(OrderNotification e, AppLocalizations l, _Amount quote) => [
  NotificationDetailRow(l.assetHistoryTime, historyTime(e.eventTime)),
  NotificationDetailRow(l.orderId, e.orderId, copyable: true),
  NotificationDetailRow(l.liveOrderClientId, e.clientOrderId, copyable: true),
  NotificationDetailRow(l.openOrdersSide, e.side == 'BUY' ? l.openOrdersBuy : l.openOrdersSell),
  NotificationDetailRow(l.notificationPositionSide, notificationSide(l, e.positionSide)),
  NotificationDetailRow(l.openOrdersOrderType, l.notificationOrderType(e.orderType)),
  NotificationDetailRow(l.openOrdersOrderPrice, quote(e.price)),
  if (e.triggerPrice != null)
    NotificationDetailRow(l.openOrdersTriggerPrice, quote(e.triggerPrice!)),
  if (e.workingType != null)
    NotificationDetailRow(
      l.notificationWorkingType,
      e.workingType == 'MARK_PRICE' ? l.openOrdersMarkPrice : l.openOrdersLastPrice,
    ),
  NotificationDetailRow(
    l.openOrdersReduceOnly,
    e.reduceOnly ? l.notificationYes : l.notificationNo,
  ),
  if (e.closePosition != null)
    NotificationDetailRow(
      l.openOrdersClosePosition,
      e.closePosition! ? l.notificationYes : l.notificationNo,
    ),
];

List<Widget> _executionRows(
  OrderNotification e,
  AppLocalizations l,
  _Amount base,
  _Amount quote,
  _Amount margin,
) => [
  NotificationDetailRow(l.notificationExecutionType, l.notificationExecution(e.executionType)),
  NotificationDetailRow(l.notificationLastQuantity, base(e.lastQuantity)),
  NotificationDetailRow(l.notificationCumulativeQuantity, base(e.filledQuantity)),
  NotificationDetailRow(l.notificationLastPrice, quote(e.lastPrice)),
  NotificationDetailRow(l.historyAveragePrice, quote(e.averagePrice)),
  NotificationDetailRow(l.historyTradeId, e.tradeId, copyable: true),
  if (e.fee != null)
    NotificationDetailRow(l.historyCommission, notificationAmount(e.fee!, e.feeAsset, l)),
  NotificationDetailRow(
    l.notificationRealizedPnl,
    margin(e.realizedPnl),
    color: notificationPnlColor(e.realizedPnl),
  ),
];

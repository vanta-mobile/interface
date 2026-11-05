import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_history.dart';
import 'futures_history_labels.dart';

class FuturesHistoryRecordCard extends StatelessWidget {
  const FuturesHistoryRecordCard({super.key, required this.record});
  final FuturesHistoryRecord record;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), r = record;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.symbol.isNotEmpty)
            SelectableText(r.symbol, style: Theme.of(context).textTheme.titleMedium),
          ...switch (r) {
            FuturesOrderRecord() => _order(l10n, r),
            FuturesTradeRecord() => _trade(l10n, r),
            FuturesIncomeRecord() => _income(l10n, r),
          },
        ],
      ),
    );
  }
}

String _time(DateTime value) => DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(value.toUtc());
String _amount(Decimal? value, String? unit, AppLocalizations l10n) =>
    value == null ? '—' : '${marketNumber(value)} ${unit ?? l10n.accountUnitUnavailable}';
Widget _reference(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label), SelectableText(value)],
  ),
);
List<Widget> _direction(AppLocalizations l10n, String side, String position) => [
  Text(
    side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell,
    style: TextStyle(color: side == 'BUY' ? AppColors.positive : AppColors.negative),
  ),
  Text(futuresHistoryPosition(l10n, position)),
];
List<Widget> _order(AppLocalizations l10n, FuturesOrderRecord r) => [
  ..._direction(l10n, r.side, r.positionSide),
  ValueRow(l10n.openOrdersStatus, futuresHistoryStatus(l10n, r.status)),
  ValueRow(l10n.openOrdersOrderType, futuresHistoryOrderType(l10n, r.type)),
  if (r.originalType != null)
    ValueRow(l10n.futuresHistoryOriginalType, futuresHistoryOrderType(l10n, r.originalType!)),
  ValueRow(l10n.historyCreatedUTC, _time(r.time)),
  ValueRow(l10n.historyUpdatedUTC, _time(r.updatedAt)),
  ValueRow(
    l10n.historyTradeQuantity,
    r.closePosition == true
        ? l10n.openOrdersClosePosition
        : _amount(r.quantity, r.units?.base, l10n),
  ),
  ValueRow(l10n.futuresHistoryExecuted, _amount(r.executed, r.units?.base, l10n)),
  ValueRow(
    l10n.openOrdersOrderPrice,
    r.price > Decimal.zero
        ? _amount(r.price, r.units?.quote, l10n)
        : r.type == 'MARKET'
        ? l10n.openOrdersMarket
        : '—',
  ),
  ValueRow(
    l10n.historyAveragePrice,
    r.executed > Decimal.zero && r.averagePrice != null && r.averagePrice! > Decimal.zero
        ? _amount(r.averagePrice, r.units?.quote, l10n)
        : '—',
  ),
  ValueRow(l10n.historyExecutedQuote, _amount(r.quoteFilled, r.units?.quote, l10n)),
  if ((r.originalType ?? r.type) == 'TRAILING_STOP_MARKET') ...[
    if (r.activationPrice case final v? when v > Decimal.zero)
      ValueRow(l10n.openOrdersActivationPrice, _amount(v, r.units?.quote, l10n)),
    if (r.callbackRate case final v?) ValueRow(l10n.openOrdersCallbackRate, '${marketNumber(v)}%'),
  ] else if (r.stopPrice case final v? when v > Decimal.zero)
    ValueRow(l10n.openOrdersTriggerPrice, _amount(v, r.units?.quote, l10n)),
  if (r.workingType != null)
    ValueRow(l10n.liveOrderTriggerBasis, switch (r.workingType) {
      'MARK_PRICE' => l10n.openOrdersMarkPrice,
      'CONTRACT_PRICE' => l10n.openOrdersLastPrice,
      _ => l10n.historyUnknownCode(r.workingType!),
    }),
  if (r.timeInForce != null)
    ValueRow(
      l10n.liveOrderPolicy,
      r.timeInForce == 'HIDDEN' ? l10n.openOrdersHidden : r.timeInForce!,
    ),
  if (r.reduceOnly == true) Text(l10n.openOrdersReduceOnly),
  if (r.priceProtect == true) Text(l10n.liveOrderTriggerProtect),
  _reference(l10n.orderId, r.orderId),
  if (r.clientOrderId != null) _reference(l10n.liveOrderClientId, r.clientOrderId!),
];
List<Widget> _trade(AppLocalizations l10n, FuturesTradeRecord r) => [
  ..._direction(l10n, r.side, r.positionSide),
  ValueRow(l10n.historyExecutionUTC, _time(r.time)),
  ValueRow(l10n.price, _amount(r.price, r.units?.quote, l10n)),
  ValueRow(l10n.historyTradeQuantity, _amount(r.quantity, r.units?.base, l10n)),
  ValueRow(l10n.historyExecutedQuote, _amount(r.quoteQuantity, r.units?.quote, l10n)),
  ValueRow(l10n.historyCommission, _amount(r.commission, r.commissionAsset, l10n)),
  ValueRow(l10n.notificationRealizedPnl, _amount(r.realizedPnl, r.units?.margin, l10n)),
  ValueRow(l10n.historyLiquidity, r.maker ? l10n.historyMaker : l10n.historyTaker),
  Text(l10n.futuresHistoryPnlHint, style: const TextStyle(color: AppColors.secondary)),
  _reference(l10n.historyTradeId, r.tradeId),
  _reference(l10n.orderId, r.orderId),
];
List<Widget> _income(AppLocalizations l10n, FuturesIncomeRecord r) => [
  SelectableText(r.asset),
  ValueRow(l10n.historyEventUTC, _time(r.time)),
  ValueRow(l10n.historyTransactionType, futuresIncomeLabel(l10n, r.type)),
  SelectableText(r.type),
  ValueRow(
    l10n.futuresHistoryIncomeAmount,
    '${r.income > Decimal.zero ? '+' : ''}${_amount(r.income, r.asset, l10n)}',
    color: r.income > Decimal.zero
        ? AppColors.positive
        : r.income < Decimal.zero
        ? AppColors.negative
        : AppColors.text,
  ),
  _reference(l10n.historyTransactionId, r.transactionId),
  if (r.tradeId != null) _reference(l10n.historyTradeId, r.tradeId!),
];

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/spot_history.dart';

class SpotHistoryRecordCard extends StatelessWidget {
  const SpotHistoryRecordCard({super.key, required this.record});
  final SpotHistoryRecord record;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = record;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.symbol.isNotEmpty)
            SelectableText(r.symbol, style: Theme.of(context).textTheme.titleMedium),
          ...switch (r) {
            SpotOrderRecord() => _orderFields(l10n, r),
            SpotTradeRecord() => _tradeFields(l10n, r),
            SpotTransactionRecord() => _transactionFields(l10n, r),
          },
        ],
      ),
    );
  }
}

String _time(DateTime date) => DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(date.toUtc());
String _amount(Decimal value, String? unit, AppLocalizations l10n) =>
    '${marketNumber(value)} ${unit ?? l10n.accountUnitUnavailable}';
Widget _reference(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label), SelectableText(value)],
  ),
);
Widget _side(AppLocalizations l10n, String side) => Text(
  side == 'BUY' ? l10n.spotSideBuy : l10n.spotSideSell,
  style: TextStyle(color: side == 'BUY' ? AppColors.positive : AppColors.negative),
);

List<Widget> _orderFields(AppLocalizations l10n, SpotOrderRecord r) => [
  _side(l10n, r.side),
  ValueRow(l10n.openOrdersStatus, switch (r.status) {
    'NEW' => l10n.openOrdersNew,
    'PARTIALLY_FILLED' => l10n.openOrdersPartiallyFilled,
    'FILLED' => l10n.historyFilled,
    'CANCELED' => l10n.historyCanceled,
    'EXPIRED' || 'EXPIRED_IN_MATCH' => l10n.historyExpired,
    'REJECTED' => l10n.historyRejected,
    'PENDING_CANCEL' => l10n.historyPendingCancel,
    _ => l10n.historyUnknownCode(r.status),
  }),
  ValueRow(
    l10n.openOrdersOrderType,
    r.timeInForce == 'HIDDEN'
        ? l10n.openOrdersHidden
        : switch (r.type) {
            'LIMIT' => l10n.openOrdersLimit,
            'MARKET' => l10n.openOrdersMarket,
            'STOP_LOSS' => l10n.openOrdersStopMarket,
            'STOP_LOSS_LIMIT' => l10n.openOrdersStopLimit,
            'TAKE_PROFIT' => l10n.openOrdersTakeProfitMarket,
            'TAKE_PROFIT_LIMIT' => l10n.openOrdersTakeProfitLimit,
            _ => l10n.historyUnknownCode(r.type),
          },
  ),
  ValueRow(l10n.historyCreatedUTC, _time(r.time)),
  ValueRow(l10n.historyUpdatedUTC, _time(r.updatedAt)),
  ValueRow(
    l10n.openOrdersFilledTotal,
    '${_amount(r.executed, r.units?.base, l10n)} / ${_amount(r.quantity, r.units?.base, l10n)}',
  ),
  ValueRow(
    l10n.openOrdersOrderPrice,
    r.price > Decimal.zero
        ? _amount(r.price, r.units?.quote, l10n)
        : r.type == 'MARKET' || r.type == 'STOP_LOSS' || r.type == 'TAKE_PROFIT'
        ? l10n.openOrdersMarket
        : '—',
  ),
  ValueRow(
    l10n.historyAveragePrice,
    r.executed > Decimal.zero && r.averagePrice != null && r.averagePrice! > Decimal.zero
        ? _amount(r.averagePrice!, r.units?.quote, l10n)
        : '—',
  ),
  ValueRow(l10n.historyExecutedQuote, _amount(r.quoteFilled, r.units?.quote, l10n)),
  if (r.stopPrice != null && r.stopPrice! > Decimal.zero)
    ValueRow(l10n.openOrdersTriggerPrice, _amount(r.stopPrice!, r.units?.quote, l10n)),
  _reference(l10n.orderId, r.orderId),
];

List<Widget> _tradeFields(AppLocalizations l10n, SpotTradeRecord r) => [
  _side(l10n, r.side),
  ValueRow(l10n.historyExecutionUTC, _time(r.time)),
  ValueRow(l10n.price, _amount(r.price, r.units?.quote, l10n)),
  ValueRow(l10n.historyTradeQuantity, _amount(r.quantity, r.units?.base, l10n)),
  ValueRow(l10n.historyExecutedQuote, _amount(r.quoteQuantity, r.units?.quote, l10n)),
  ValueRow(l10n.historyCommission, _amount(r.commission, r.commissionAsset, l10n)),
  ValueRow(l10n.historyLiquidity, r.maker ? l10n.historyMaker : l10n.historyTaker),
  _reference(l10n.historyTradeId, r.tradeId),
  _reference(l10n.orderId, r.orderId),
];

List<Widget> _transactionFields(AppLocalizations l10n, SpotTransactionRecord r) => [
  SelectableText(r.asset),
  ValueRow(l10n.historyEventUTC, _time(r.time)),
  ValueRow(l10n.historyTransactionType, switch (r.type) {
    'DEPOSIT' => l10n.historyDeposit,
    'WITHDRAW' => l10n.historyWithdraw,
    'TRANSFER' || 'INTERNAL_TRANSFER' => l10n.historyTransfer,
    'TRADE_SOURCE' => l10n.historyTradeSource,
    'TRADE_TARGET' => l10n.historyTradeTarget,
    'AIRDROP' => l10n.historyAirdrop,
    'DIVIDEND' => l10n.historyDividend,
    'SWAP' => l10n.historySwap,
    'COMMISSION_REBATE' => l10n.historyRebate,
    _ => l10n.historyUnknownCode(r.type),
  }),
  ValueRow(
    l10n.historyBalanceChange,
    '${r.delta > Decimal.zero ? '+' : ''}${_amount(r.delta, r.asset, l10n)}',
    color: r.delta > Decimal.zero
        ? AppColors.positive
        : r.delta < Decimal.zero
        ? AppColors.negative
        : AppColors.text,
  ),
  _reference(l10n.historyTransactionId, r.transactionId),
  if (r.tradeId != null) _reference(l10n.historyTradeId, r.tradeId!),
];

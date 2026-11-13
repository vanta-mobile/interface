import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/spot_open_orders.dart';

class SpotOpenOrderCard extends StatelessWidget {
  const SpotOpenOrderCard({super.key, required this.order});
  final SpotOpenOrder order;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), o = order;
    String amount(Decimal? v, String? unit) =>
        v == null ? '—' : '$v ${unit ?? l10n.accountUnitUnavailable}';
    String time(DateTime? v) =>
        v == null ? l10n.openOrdersCreationUnknown : v.toUtc().toIso8601String();
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(o.symbol, style: Theme.of(context).textTheme.titleMedium),
          Text(
            o.side == 'BUY' ? l10n.spotSideBuy : l10n.spotSideSell,
            style: TextStyle(color: o.side == 'BUY' ? AppColors.positive : AppColors.negative),
          ),
          ValueRow(l10n.openOrdersStatus, switch (o.status) {
            'NEW' => l10n.openOrdersNew,
            'PARTIALLY_FILLED' => l10n.openOrdersPartiallyFilled,
            'PENDING_CANCEL' => l10n.historyPendingCancel,
            _ => l10n.historyUnknownCode(o.status),
          }),
          ValueRow(l10n.openOrdersOrderType, _type(l10n, o.originalType ?? o.type)),
          if (o.timeInForce != null) ValueRow(l10n.spotOpenOrdersPolicy, o.timeInForce!),
          ValueRow(l10n.historyCreatedUTC, time(o.time)),
          ValueRow(l10n.historyUpdatedUTC, time(o.updatedAt)),
          ValueRow(
            l10n.openOrdersFilledTotal,
            '${amount(o.executed, o.units?.base)} / ${amount(o.quantity > Decimal.zero ? o.quantity : null, o.units?.base)}',
          ),
          if (o.quantity == Decimal.zero) Text(l10n.spotOpenOrdersQuantityUnknown),
          ValueRow(l10n.openOrdersRemaining, amount(o.remaining, o.units?.base)),
          if (o.quoteOrderQuantity != null)
            ValueRow(
              l10n.spotOpenOrdersQuoteQuantity,
              amount(o.quoteOrderQuantity, o.units?.quote),
            ),
          ValueRow(
            l10n.openOrdersOrderPrice,
            o.price > Decimal.zero
                ? amount(o.price, o.units?.quote)
                : const {
                    'MARKET',
                    'STOP_MARKET',
                    'TAKE_PROFIT_MARKET',
                    'STOP_LOSS',
                  }.contains(o.type)
                ? l10n.openOrdersMarket
                : '—',
          ),
          ValueRow(
            l10n.historyAveragePrice,
            o.executed > Decimal.zero && (o.averagePrice ?? Decimal.zero) > Decimal.zero
                ? amount(o.averagePrice, o.units?.quote)
                : '—',
          ),
          ValueRow(l10n.historyExecutedQuote, amount(o.quoteFilled, o.units?.quote)),
          if ((o.stopPrice ?? Decimal.zero) > Decimal.zero)
            ValueRow(l10n.openOrdersTriggerPrice, amount(o.stopPrice, o.units?.quote)),
          Text(l10n.orderId),
          SelectableText(o.orderId),
          Text(l10n.liveOrderClientId),
          SelectableText(o.clientOrderId),
        ],
      ),
    );
  }

  String _type(AppLocalizations l10n, String code) => switch (code) {
    'LIMIT' => l10n.openOrdersLimit,
    'MARKET' => l10n.openOrdersMarket,
    'STOP' || 'STOP_LOSS_LIMIT' => l10n.openOrdersStopLimit,
    'STOP_MARKET' || 'STOP_LOSS' => l10n.openOrdersStopMarket,
    'TAKE_PROFIT' || 'TAKE_PROFIT_LIMIT' => l10n.openOrdersTakeProfitLimit,
    'TAKE_PROFIT_MARKET' => l10n.openOrdersTakeProfitMarket,
    _ => l10n.historyUnknownCode(code),
  };
}

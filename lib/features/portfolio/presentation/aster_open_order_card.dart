import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/aster_open_orders.dart';

class AsterOpenOrderCard extends StatelessWidget {
  const AsterOpenOrderCard({super.key, required this.order, this.onCancel});
  final AsterOpenOrder order;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = order.units?.base ?? l10n.accountUnitUnavailable;
    final quote = order.units?.quote ?? l10n.accountUnitUnavailable;
    String amount(Decimal value, String unit) => '${marketNumber(value)} $unit';
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(order.symbol, style: Theme.of(context).textTheme.titleMedium),
              Text(
                order.side == 'BUY' ? l10n.openOrdersBuy : l10n.openOrdersSell,
                style: TextStyle(
                  color: order.side == 'BUY' ? AppColors.positive : AppColors.negative,
                ),
              ),
              Text(_positionSide(l10n, order.positionSide)),
            ],
          ),
          const SizedBox(height: 8),
          ValueRow(l10n.openOrdersOrderType, _orderType(l10n, order)),
          ValueRow(
            l10n.openOrdersStatus,
            order.status == 'NEW' ? l10n.openOrdersNew : l10n.openOrdersPartiallyFilled,
          ),
          ValueRow(
            l10n.openOrdersCreatedLocal,
            order.time == null
                ? l10n.openOrdersCreationUnknown
                : DateFormat('MM-dd HH:mm:ss').format(order.time!.toLocal()),
          ),
          if (order.updatedAt case final time?)
            ValueRow(
              l10n.openOrdersUpdatedUTC,
              DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toUtc()),
            ),
          ValueRow(
            l10n.openOrdersFilledTotal,
            order.closePosition
                ? l10n.openOrdersClosePosition
                : '${amount(order.executedQty, base)} / ${amount(order.origQty, base)}',
          ),
          ValueRow(
            l10n.openOrdersRemaining,
            order.closePosition ? '—' : amount(order.remainingQty, base),
          ),
          ValueRow(l10n.openOrdersOrderPrice, _price(l10n, order, quote)),
          if (order.limitNotional case final value?)
            ValueRow(l10n.openOrdersOrderValue, amount(value, quote)),
          if ((order.originalType ?? order.type) == 'TRAILING_STOP_MARKET') ...[
            if (order.activatePrice case final value? when value > Decimal.zero)
              ValueRow(l10n.openOrdersActivationPrice, amount(value, quote)),
            if (order.priceRate case final value?)
              ValueRow(l10n.openOrdersCallbackRate, '${marketNumber(value)}%'),
          ] else if (order.stopPrice case final value? when value > Decimal.zero)
            ValueRow(
              l10n.openOrdersTriggerPrice,
              '${amount(value, quote)} · ${switch (order.workingType) {
                'MARK_PRICE' => l10n.openOrdersMarkPrice,
                'CONTRACT_PRICE' => l10n.openOrdersLastPrice,
                _ => l10n.openOrdersUnknownTrigger,
              }}',
            ),
          if (order.reduceOnly)
            Text(l10n.openOrdersReduceOnly, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(l10n.orderId, style: Theme.of(context).textTheme.bodySmall),
          SelectableText(order.orderId, key: Key('open-order-${order.symbol}-${order.orderId}')),
          const SizedBox(height: 12),
          OutlinedButton(
            key: Key('cancel-order-${order.symbol}-${order.orderId}'),
            onPressed: onCancel,
            child: Text(l10n.orderCancelTitle),
          ),
        ],
      ),
    );
  }
}

String _positionSide(AppLocalizations l10n, String value) => switch (value) {
  'LONG' => l10n.openOrdersLongSide,
  'SHORT' => l10n.openOrdersShortSide,
  _ => l10n.openOrdersOneWay,
};

String _orderType(AppLocalizations l10n, AsterOpenOrder order) {
  if (order.timeInForce == 'HIDDEN') return l10n.openOrdersHidden;
  return switch (order.originalType ?? order.type) {
    'LIMIT' => l10n.openOrdersLimit,
    'MARKET' => l10n.openOrdersMarket,
    'STOP' => l10n.openOrdersStopLimit,
    'STOP_MARKET' => l10n.openOrdersStopMarket,
    'TAKE_PROFIT' => l10n.openOrdersTakeProfitLimit,
    'TAKE_PROFIT_MARKET' => l10n.openOrdersTakeProfitMarket,
    'TRAILING_STOP_MARKET' => l10n.openOrdersTrailingStop,
    _ => l10n.openOrdersOtherType,
  };
}

String _price(AppLocalizations l10n, AsterOpenOrder order, String quote) {
  if (order.pegPriceType != null && order.price == Decimal.zero) {
    return l10n.openOrdersBbo;
  }
  if (order.price > Decimal.zero) return '${marketNumber(order.price)} $quote';
  if (order.type == 'MARKET' || order.type.endsWith('_MARKET')) {
    return l10n.openOrdersMarket;
  }
  return '—';
}

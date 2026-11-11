import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/aster_open_orders.dart';
import 'open_order_labels.dart';
import 'portfolio_components.dart';

/// "Order details" sheet from the Open Orders design. Aster's open-order read
/// carries no linked-order graph, so a single order block is shown.
Future<void> showOpenOrderDetails(BuildContext context, AsterOpenOrder order) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: TradeColors.sheet,
      barrierColor: TradeColors.scrim,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: TradeColors.card),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OpenOrderDetails(order: order),
    );

class _OpenOrderDetails extends StatelessWidget {
  const _OpenOrderDetails({required this.order});
  final AsterOpenOrder order;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = order.units?.base ?? l10n.accountUnitUnavailable;
    final quote = order.units?.quote ?? l10n.accountUnitUnavailable;
    final buy = order.side == 'BUY';
    final trigger = openOrderTrigger(l10n, order);
    final price = openOrderPrice(l10n, order);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('open-order-details'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.openOrdersDetailsTitle, style: TradeTypography.heading),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const PortfolioIcon('close.svg', size: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1, color: TradeColors.line),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: TradeColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    order.symbol,
                    style: TradeTypography.body.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    openOrderType(l10n, order),
                    order.status == 'NEW' ? l10n.openOrdersNew : l10n.openOrdersPartiallyFilled,
                  ),
                  _DetailRow(
                    l10n.openOrdersSide,
                    buy ? l10n.openOrdersBuy : l10n.openOrdersSell,
                    color: buy ? TradeColors.positive : TradeColors.negative,
                  ),
                  _DetailRow(
                    l10n.openOrdersFilledTotal,
                    order.closePosition
                        ? l10n.openOrdersClosePosition
                        : '${marketNumber(order.executedQty)} / ${marketNumber(order.origQty)} $base',
                  ),
                  _DetailRow(
                    l10n.openOrdersOrderPrice,
                    order.price > Decimal.zero ? '$price $quote' : price,
                  ),
                  if (trigger != null) _DetailRow(l10n.openOrdersTriggerPrice, trigger),
                  _DetailRow(
                    l10n.openOrdersReduceOnly,
                    order.reduceOnly || order.closePosition
                        ? l10n.openOrdersYes
                        : l10n.openOrdersNo,
                  ),
                  if (order.time case final time?)
                    _DetailRow(
                      l10n.openOrdersCreatedLocal,
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toLocal()),
                    ),
                  _DetailRow(l10n.orderId, order.orderId, copyable: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.color, this.copyable = false});
  final String label, value;
  final Color? color;
  final bool copyable;
  @override
  Widget build(BuildContext context) {
    final style = TradeTypography.body.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: copyable
                ? SelectableText(value, style: style, textAlign: TextAlign.end)
                : Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

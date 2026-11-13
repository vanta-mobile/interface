import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/coin_icon.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../application/order_explorer_provider.dart';
import '../domain/aster_open_orders.dart';
import 'open_order_labels.dart';
import 'portfolio_components.dart';

class AsterOpenOrderCard extends StatelessWidget {
  const AsterOpenOrderCard({
    super.key,
    required this.order,
    this.leverage,
    this.strategy,
    this.onCancel,
    this.onViewChart,
    this.onTap,
    this.editable = false,
    this.onEdit,
  });
  final AsterOpenOrder order;
  final int? leverage;

  /// OTO/OTOCO linkage: entry orders show their TP/SL, exit legs their strategy.
  final OpenOrderStrategy? strategy;
  final VoidCallback? onCancel;

  /// Shown only while the chart displays a different symbol.
  final VoidCallback? onViewChart;

  /// Opens the order's market; the card is inert without it.
  final VoidCallback? onTap;

  /// Shows the Edit chip (LIMIT orders without TP/SL); [onEdit] null disables it.
  final bool editable;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = order.units?.base ?? l10n.accountUnitUnavailable;
    final quote = order.units?.quote ?? l10n.accountUnitUnavailable;
    final trailing = isTrailingOrder(order);
    final value = order.limitNotional;
    return Material(
      key: Key('open-order-${order.symbol}-${order.orderId}'),
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: PortfolioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(order: order, onViewChart: onViewChart),
              const SizedBox(height: 8),
              _Tags(order: order, leverage: leverage),
              const SizedBox(height: 20),
              _AmountBlock(
                label: l10n.openOrdersAmountUnit(base),
                amount: order.closePosition
                    ? l10n.openOrdersClosePosition
                    : '${marketNumber(order.executedQty)} / ${marketNumber(order.origQty)}',
                priceLabel: l10n.openOrdersOrderPrice,
                price: openOrderPrice(l10n, order),
              ),
              _Row(
                l10n.openOrdersOrderValue,
                value == null ? openOrderPlaceholder : '${marketNumber(value)} $quote',
              ),
              if (trailing) ...[
                if (order.activatePrice case final price? when price > Decimal.zero)
                  _Row(l10n.openOrdersActivationPrice, '${marketNumber(price)} $quote'),
                if (order.priceRate case final rate?)
                  _Row(l10n.openOrdersCallbackRate, '${marketNumber(rate)}%'),
              ] else
                _Row(
                  l10n.openOrdersTriggerPrice,
                  openOrderTrigger(l10n, order) ?? openOrderPlaceholder,
                ),
              if (isConditionalOrder(order) || order.reduceOnly)
                _Row(
                  l10n.openOrdersReduceOnly,
                  order.reduceOnly || order.closePosition ? l10n.openOrdersYes : l10n.openOrdersNo,
                ),
              if (strategy case final linked? when linked.entry && linked.hasExits)
                _TpSlRow(label: l10n.openOrdersTpSl, strategy: linked),
              if (strategy case final linked? when !linked.entry)
                _Row(
                  l10n.openOrdersLinkedOrder,
                  linked.strategyId,
                  color: TradeColors.warning,
                  copyable: true,
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) => OpenOrderChipButton(
                        key: Key('open-order-explorer-${order.symbol}-${order.orderId}'),
                        label: l10n.openOrdersViewExplorer,
                        onPressed: order.transactionHash == null
                            ? null
                            : () => ref.read(orderExplorerLauncherProvider)(
                                orderExplorerUri(order.transactionHash!),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: editable ? 8 : 12),
                  Expanded(
                    child: OpenOrderChipButton(
                      key: Key('cancel-order-${order.symbol}-${order.orderId}'),
                      label: l10n.cancel,
                      onPressed: onCancel,
                    ),
                  ),
                  if (editable) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OpenOrderChipButton(
                        key: Key('edit-order-${order.symbol}-${order.orderId}'),
                        label: l10n.openOrdersEdit,
                        onPressed: onEdit,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.onViewChart});
  final AsterOpenOrder order;
  final VoidCallback? onViewChart;
  @override
  Widget build(BuildContext context) {
    final units = order.units;
    final base = units?.base;
    final quote = units != null && order.symbol == '${units.base}${units.quote}'
        ? units.quote
        : null;
    return Row(
      children: [
        CoinIcon(base: base ?? order.symbol, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: quote == null ? order.symbol : base),
                if (quote != null)
                  TextSpan(
                    text: quote,
                    style: const TextStyle(color: TradeColors.secondary),
                  ),
              ],
            ),
            style: TradeTypography.heading,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onViewChart != null)
          IconButton(
            key: Key('open-order-chart-${order.symbol}-${order.orderId}'),
            tooltip: AppLocalizations.of(context).openOrdersViewChart(order.symbol),
            onPressed: onViewChart,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            icon: const TradeIcon('order-chart', color: TradeColors.text),
          ),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.order, required this.leverage});
  final AsterOpenOrder order;
  final int? leverage;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buy = order.side == 'BUY';
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Tag(
          buy ? l10n.openOrdersBuy : l10n.openOrdersSell,
          color: buy ? TradeColors.positive : TradeColors.negative,
          background: buy ? TradeColors.buyLabel : TradeColors.sellLabel,
        ),
        _Tag(openOrderType(l10n, order)),
        if (leverage case final value?) _Tag('${value}x'),
        Text(
          order.time == null
              ? l10n.openOrdersCreationUnknown
              : DateFormat('MM-dd HH:mm:ss').format(order.time!.toLocal()),
          style: TradeTypography.tag.copyWith(color: TradeColors.secondary),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color = TradeColors.text, this.background = TradeColors.card});
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TradeTypography.tag.copyWith(color: color)),
  );
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.label,
    required this.amount,
    required this.priceLabel,
    required this.price,
  });
  final String label, amount, priceLabel, price;
  static const _value = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: TradeColors.text,
  );
  @override
  Widget build(BuildContext context) {
    final caption = TradeTypography.body.copyWith(color: TradeColors.secondary);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: TradeColors.sheet, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: caption),
                const SizedBox(height: 4),
                Text(amount, style: _value),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(priceLabel, style: caption, textAlign: TextAlign.end),
                const SizedBox(height: 4),
                Text(price, style: _value, textAlign: TextAlign.end),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.copyable = false});
  final String label, value;
  final Color? color;
  final bool copyable;
  @override
  Widget build(BuildContext context) {
    final style = TradeTypography.body.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
          ),
          const SizedBox(width: 12),
          // Align fills the loose half so short values stay flush right.
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: copyable
                  ? SelectableText(value, style: style, textAlign: TextAlign.end)
                  : Text(value, style: style, textAlign: TextAlign.end),
            ),
          ),
        ],
      ),
    );
  }
}

class _TpSlRow extends StatelessWidget {
  const _TpSlRow({required this.label, required this.strategy});
  final String label;
  final OpenOrderStrategy strategy;
  @override
  Widget build(BuildContext context) {
    TextSpan price(Decimal? value, Color color) => TextSpan(
      text: value == null ? openOrderPlaceholder : marketNumber(value),
      style: TextStyle(color: value == null ? TradeColors.text : color),
    );
    return Padding(
      key: const Key('open-order-tpsl'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text.rich(
                TextSpan(
                  children: [
                    price(strategy.takeProfit, TradeColors.positive),
                    const TextSpan(text: ' / '),
                    price(strategy.stopLoss, TradeColors.negative),
                  ],
                ),
                style: TradeTypography.body,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width card action from the design ("Chip"): 32 px tall, raised fill.
/// While [pending] it is disabled and shows a spinner.
class OpenOrderChipButton extends StatelessWidget {
  const OpenOrderChipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.pending = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool pending;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: pending ? null : onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(32),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      tapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: TradeColors.control,
      foregroundColor: TradeColors.text,
      disabledBackgroundColor: TradeColors.control.withValues(alpha: .5),
      disabledForegroundColor: TradeColors.muted,
      side: const BorderSide(color: TradeColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    child: pending
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: TradeColors.text),
          )
        : Text(label),
  );
}

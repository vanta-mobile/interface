import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/coin_icon.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../../trade/presentation/widgets/trade_tooltip.dart';
import '../domain/aster_open_orders.dart';
import '../domain/position_card_metrics.dart';
import '../domain/position_returns.dart';
import '../domain/position_risk.dart';
import '../domain/position_valuation.dart';
import 'aster_open_order_card.dart' show OpenOrderChipButton;
import 'open_order_labels.dart' show openOrderPlaceholder;
import 'portfolio_components.dart';
import 'position_valuation_rows.dart';

part 'trade_position_card_rows.dart';

/// Position card shared by the Futures Positions tab and the Portfolio page.
/// Mark, PnL and size follow the live public mark when it is newer than the
/// signed snapshot. [hidden] masks amounts and prices for balance hiding.
class TradePositionCard extends ConsumerWidget {
  const TradePositionCard({
    super.key,
    required this.position,
    required this.exits,
    this.marginRatio,
    this.onTpSl,
    this.onMarket,
    this.onLimit,
    this.onAdjustMargin,
    this.onEditPartial,
    this.hidden = false,
  });
  final PositionRisk position;
  final PositionExitOrders exits;
  final Decimal? marginRatio;
  final VoidCallback? onTpSl, onMarket, onLimit, onAdjustMargin, onEditPartial;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), p = position;
    final (quote, _) = watchPositionMark(ref, p);
    final values = PositionValuation(position: p, quote: quote);
    final pnl = quote == null ? p.unrealizedProfit : values.unrealizedProfit;
    final returns = PositionReturns(position: p, mark: values.mark, pnl: pnl);
    final liquidation = p.liquidationPrice != null && p.liquidationPrice! > Decimal.zero
        ? p.liquidationPrice
        : null;
    final id = '${p.symbol}-${p.side}';
    return PortfolioCard(
      key: Key('trade-position-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(position: p, marginRatio: marginRatio),
          const SizedBox(height: 16),
          _PnlBlock(
            position: p,
            pnl: pnl,
            roe: returns.roePercent,
            size: (values.notional ?? p.notional)?.abs(),
            hidden: hidden,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Metric(l10n.positionsEntry, _price(p.entryPrice))),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  l10n.portfolioMark,
                  _price(values.mark),
                  alignment: CrossAxisAlignment.center,
                  animated: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  l10n.portfolioLiquidation,
                  _price(liquidation),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _LiquidationBar(
            progress: liquidationProgress(
              entry: p.entryPrice,
              mark: values.mark,
              liquidation: liquidation,
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: l10n.positionsMargin,
            child: _ActionValue(
              value: Text(
                hidden
                    ? hiddenAmount
                    : returns.margin == null
                    ? openOrderPlaceholder
                    : '${portfolioAmount(returns.margin)} '
                          '${p.units?.margin ?? l10n.accountUnitUnavailable}',
                style: TradeTypography.body,
              ),
              action: onAdjustMargin == null
                  ? null
                  : _InlineIcon(
                      key: Key('trade-position-margin-$id'),
                      asset: 'position-add',
                      size: 12,
                      color: TradeColors.positive,
                      tooltip: l10n.marginAdjustTitle,
                      onTap: onAdjustMargin!,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          _Row(
            label: l10n.positionsEntireTpsl,
            child: _ExitPrices(exits.entireTakeProfit, exits.entireStopLoss, hidden: hidden),
          ),
          const SizedBox(height: 8),
          _Row(
            label: l10n.positionsPartialTpsl(exits.partialCount),
            child: _ActionValue(
              value: _ExitPrices(exits.partialTakeProfit, exits.partialStopLoss, hidden: hidden),
              action: onEditPartial == null
                  ? null
                  : _InlineIcon(
                      key: Key('trade-position-partial-$id'),
                      asset: 'position-edit',
                      size: 14,
                      color: TradeColors.secondary,
                      tooltip: l10n.positionsEditPartialTpsl,
                      onTap: onEditPartial!,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (index, (label, action)) in [
                (l10n.portfolioTpsl, onTpSl),
                (l10n.market, onMarket),
                (l10n.limit, onLimit),
              ].indexed) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: OpenOrderChipButton(
                    key: Key('trade-position-action-$index-$id'),
                    label: label,
                    onPressed: action,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _price(Decimal? value) => hidden
      ? hiddenAmount
      : value == null
      ? openOrderPlaceholder
      : '\$${marketNumber(value)}';
}

/// Masked value shown while balances are hidden.
const hiddenAmount = '••••';

class _Header extends StatelessWidget {
  const _Header({required this.position, required this.marginRatio});
  final PositionRisk position;
  final Decimal? marginRatio;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), p = position, units = p.units;
    final quote = units != null && p.symbol == '${units.base}${units.quote}' ? units.quote : null;
    final ratio = marginRatio;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoinIcon(base: units?.base ?? p.symbol, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: quote == null ? p.symbol : units!.base),
                          if (quote != null)
                            TextSpan(
                              text: quote,
                              style: const TextStyle(color: TradeColors.secondary),
                            ),
                        ],
                      ),
                      style: TradeTypography.heading,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  PositionTag(
                    p.long ? l10n.openOrdersBuy : l10n.openOrdersSell,
                    color: p.long ? TradeColors.positive : TradeColors.negative,
                    background: p.long ? TradeColors.buyLabel : TradeColors.sellLabel,
                  ),
                  if (p.leverage case final leverage?) PositionTag('${leverage}x'),
                  PositionTag(p.isolated ? l10n.accountIsolatedMode : l10n.cross),
                ],
              ),
            ],
          ),
        ),
        if (ratio != null) ...[
          const SizedBox(width: 20),
          TradeTooltip(
            tooltipKey: const Key('trade-position-margin-tip'),
            message: l10n.positionsMarginRatioTip,
            child: Semantics(
              label: l10n.positionsMarginRatio('${ratio.toStringAsFixed(2)}%'),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    SizedBox.square(
                      key: const Key('trade-position-margin-gauge'),
                      dimension: 28,
                      child: OverflowBox(
                        maxWidth: 30.17,
                        maxHeight: 30.17,
                        child: Stack(
                          children: [
                            const PortfolioIcon('risk-arc.svg', size: 30.17),
                            // The needle shares the arc's centre, so it turns in place.
                            Transform.rotate(
                              key: const Key('trade-position-margin-needle'),
                              angle: marginGaugeRotation(ratio),
                              child: const PortfolioIcon('risk-needle.svg', size: 30.17),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${ratio.toStringAsFixed(2)}%',
                      style: TradeTypography.caption.copyWith(
                        color: TradeColors.positive,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bordered position tag (side, leverage, margin mode, order type).
class PositionTag extends StatelessWidget {
  const PositionTag(
    this.label, {
    super.key,
    this.color = TradeColors.text,
    this.background = TradeColors.card,
  });
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: TradeColors.control),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: TradeTypography.tag.copyWith(color: color)),
  );
}

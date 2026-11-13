import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/position_risk.dart';
import 'open_order_labels.dart' show openOrderPlaceholder;
import 'portfolio_components.dart' show portfolioAmount;
import 'trade_position_card.dart' show PositionTag;

/// Position summary card of the Set TP/SL page and the Close Position sheet:
/// symbol with side, order type and leverage tags above label/value rows.
class PositionOrderSummary extends StatelessWidget {
  const PositionOrderSummary({
    super.key,
    required this.position,
    required this.limit,
    required this.rows,
    this.bordered = false,
  });
  final PositionRisk position;

  /// Whether the order executes as a limit order once placed or triggered.
  final bool limit;
  final List<(String, Widget)> rows;

  /// The close sheet's card has the divider border; the TP/SL page's has none.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), p = position;
    return Container(
      key: const Key('position-order-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TradeColors.card,
        borderRadius: BorderRadius.circular(12),
        border: bordered ? Border.all(color: TradeColors.line) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(p.symbol, style: TradeTypography.symbol),
              PositionTag(
                p.long ? l10n.openOrdersBuy : l10n.openOrdersSell,
                color: p.long ? TradeColors.positive : TradeColors.negative,
                background: p.long ? TradeColors.buyLabel : TradeColors.sellLabel,
              ),
              PositionTag(limit ? l10n.limit : l10n.market),
              if (p.leverage case final leverage?) PositionTag('${leverage}x'),
            ],
          ),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              // Long amounts wrap within most of the row instead of pushing
              // the label out; short ones keep their natural width.
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TradeTypography.body.copyWith(color: TradeColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * .6),
                      child: DefaultTextStyle.merge(
                        style: TradeTypography.body,
                        textAlign: TextAlign.end,
                        child: value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Price in the position's quote unit, or the placeholder.
String summaryPrice(BuildContext context, PositionRisk p, Decimal? value) =>
    value == null || value <= Decimal.zero
    ? openOrderPlaceholder
    : '${marketNumber(value)} ${p.units?.quote ?? AppLocalizations.of(context).accountUnitUnavailable}';

/// Signed amount in the position's margin unit, or the placeholder.
String summaryPnl(BuildContext context, PositionRisk p, Decimal? value) => value == null
    ? openOrderPlaceholder
    : '${value > Decimal.zero ? '+' : ''}${portfolioAmount(value)} '
          '${p.units?.margin ?? AppLocalizations.of(context).accountUnitUnavailable}';

const summaryEstimateStyle = TextStyle(fontSize: 13, height: 18 / 13);

/// Estimated-PnL value colored by sign.
Widget summaryPnlText(BuildContext context, PositionRisk p, Decimal? value) => Text(
  summaryPnl(context, p, value),
  style: summaryEstimateStyle.copyWith(
    color: value == null || value == Decimal.zero
        ? TradeColors.text
        : value > Decimal.zero
        ? TradeColors.positive
        : TradeColors.negative,
  ),
);

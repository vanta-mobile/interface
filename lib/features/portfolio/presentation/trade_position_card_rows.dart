part of 'trade_position_card.dart';

class _PnlBlock extends StatelessWidget {
  const _PnlBlock({
    required this.position,
    required this.pnl,
    required this.roe,
    required this.size,
    required this.hidden,
  });
  final PositionRisk position;
  final Decimal? pnl, roe, size;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = position.units?.margin ?? l10n.accountUnitUnavailable;
    final caption = TradeTypography.body.copyWith(color: TradeColors.muted);
    String signed(Decimal value, String text) => value > Decimal.zero ? '+$text' : text;
    final value = pnl;
    final text = hidden
        ? hiddenAmount
        : value == null
        ? openOrderPlaceholder
        : '${signed(value, portfolioAmount(value))}'
              '${roe == null ? '' : ' (${signed(roe!, roe!.toStringAsFixed(2))}%)'}';
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
                Text(l10n.portfolioPnlUnit(unit), style: caption),
                const SizedBox(height: 4),
                AnimatedNumberText(
                  text,
                  style: TradeTypography.symbol.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                    color: hidden || value == null || value == Decimal.zero
                        ? TradeColors.text
                        : value > Decimal.zero
                        ? TradeColors.positive
                        : TradeColors.negative,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.portfolioSize(position.units?.quote ?? l10n.accountUnitUnavailable),
                  style: caption,
                  textAlign: TextAlign.end,
                ),
                const SizedBox(height: 4),
                AnimatedNumberText(
                  hidden
                      ? hiddenAmount
                      : size == null
                      ? openOrderPlaceholder
                      : portfolioAmount(size),
                  style: TradeTypography.body,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
    this.label,
    this.value, {
    this.alignment = CrossAxisAlignment.start,
    this.animated = false,
  });
  final String label, value;
  final CrossAxisAlignment alignment;
  final bool animated;
  @override
  Widget build(BuildContext context) {
    final align = switch (alignment) {
      CrossAxisAlignment.center => TextAlign.center,
      CrossAxisAlignment.end => TextAlign.right,
      _ => TextAlign.left,
    };
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: TradeTypography.body.copyWith(color: TradeColors.muted)),
        const SizedBox(height: 4),
        animated
            ? AnimatedNumberText(value, style: TradeTypography.body, textAlign: align)
            : Text(value, style: TradeTypography.body, textAlign: align),
      ],
    );
  }
}

/// Entry-to-liquidation track: the green-to-red gradient is revealed up to the
/// share of that distance the mark has covered.
class _LiquidationBar extends StatelessWidget {
  const _LiquidationBar({required this.progress});
  final double? progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).positionsLiquidationProgress,
    value: progress == null ? null : '${(progress! * 100).round()}%',
    child: SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, box) => ClipRRect(
          key: const Key('trade-position-liquidation-bar'),
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            // Design token `cards-card-secondary`, the same fill as the card.
            color: TradeColors.card,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                key: const Key('trade-position-liquidation-fill'),
                width: box.maxWidth * (progress ?? 0),
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  // The full-width gradient is revealed up to the progress.
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: box.maxWidth,
                    maxWidth: box.maxWidth,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [TradeColors.positive, TradeColors.negative],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 18),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TradeTypography.body.copyWith(color: TradeColors.muted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    ),
  );
}

class _ExitPrices extends StatelessWidget {
  const _ExitPrices(this.takeProfit, this.stopLoss, {required this.hidden});
  final AsterOpenOrder? takeProfit, stopLoss;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    String price(AsterOpenOrder? order) => hidden
        ? hiddenAmount
        : order?.stopPrice == null
        ? openOrderPlaceholder
        : marketNumber(order!.stopPrice!);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: price(takeProfit),
            style: const TextStyle(color: TradeColors.positive),
          ),
          TextSpan(
            text: '  /  ${price(stopLoss)}',
            style: const TextStyle(color: TradeColors.negative),
          ),
        ],
      ),
      style: TradeTypography.body,
      textAlign: TextAlign.end,
    );
  }
}

/// A row value followed by an optional inline action icon.
class _ActionValue extends StatelessWidget {
  const _ActionValue({required this.value, this.action});
  final Widget value;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: value),
      if (action != null) ...[const SizedBox(width: 4), action!],
    ],
  );
}

/// Small inline action icon with a 44 px touch target that does not change
/// the row height.
class _InlineIcon extends StatelessWidget {
  const _InlineIcon({
    super.key,
    required this.asset,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final String asset, tooltip;
  final double size;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: OverflowBox(
      maxWidth: 44,
      maxHeight: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: TradeIcon(asset, size: size, color: color),
      ),
    ),
  );
}

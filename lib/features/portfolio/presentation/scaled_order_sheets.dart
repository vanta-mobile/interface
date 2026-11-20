import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../domain/live_order.dart';
import '../domain/scaled_order.dart';
import '../../../core/presentation/no_press_feedback.dart';

/// Initial margin reference of a plan: total limit notional ÷ leverage,
/// rounded up to cents so the display never understates it.
Decimal scaledMargin(ScaledOrderPlan plan, LiveOrderContext data) {
  if (data.leverage <= 0) return Decimal.zero;
  final value = (plan.notional / Decimal.fromInt(data.leverage)).toDecimal(
    scaleOnInfinitePrecision: 8,
  );
  return value.ceil(scale: 2);
}

/// Quantity-weighted average limit price of the plan.
Decimal? scaledAveragePrice(ScaledOrderPlan plan) {
  final total = plan.totalQuantity;
  if (total <= Decimal.zero) return null;
  return (plan.notional / total).toDecimal(scaleOnInfinitePrecision: 6);
}

/// Preview sheet (design 10.05): every child order and the plan summary.
Future<void> showScaledPreviewSheet(
  BuildContext context, {
  required ScaledOrderPlan plan,
  required LiveOrderContext data,
}) {
  final l10n = AppLocalizations.of(context);
  return showTradeContentSheet<void>(
    context,
    key: const Key('scaled-preview-sheet'),
    title: l10n.scaledPreviewLink,
    children: (_) => [ScaledDistributionSection(plan: plan, data: data)],
  );
}

/// Size distribution heading, child order table and summary row.
class ScaledDistributionSection extends StatelessWidget {
  const ScaledDistributionSection({super.key, required this.plan, required this.data});
  final ScaledOrderPlan plan;
  final LiveOrderContext data;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = data.rules.quoteAsset, base = data.rules.baseAsset;
    final total = plan.totalQuantity, average = scaledAveragePrice(plan);
    final header = TradeTypography.body.copyWith(color: TradeColors.secondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(l10n.scaledSizeDistribution, style: TradeTypography.section),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: TradeColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _TableRow(
            cells: [
              Text(l10n.scaledSubOrderType, style: header),
              Text(l10n.scaledPriceColumn(quote), style: header, textAlign: TextAlign.center),
              Text(l10n.scaledSizeColumn(base), style: header, textAlign: TextAlign.end),
            ],
          ),
        ),
        for (final (index, order) in plan.orders.indexed)
          ConstrainedBox(
            key: ValueKey('scaled-preview-row-$index'),
            constraints: const BoxConstraints(minHeight: 40),
            child: _TableRow(
              cells: [
                Text(l10n.limit, style: TradeTypography.body),
                Text(
                  order.price,
                  style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: order.quantity,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' (${_share(order, total)}%)',
                        style: const TextStyle(color: TradeColors.secondary),
                      ),
                    ],
                  ),
                  style: TradeTypography.body,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 4,
          children: [
            _Summary(l10n.scaledAveragePrice, average?.toStringAsFixed(6) ?? '—'),
            _Summary(l10n.tradeMargin, '${scaledMargin(plan, data).toStringAsFixed(2)} $quote'),
          ],
        ),
      ],
    );
  }

  static String _share(LiveOrderDraft order, Decimal total) {
    final quantity = parseOrderDecimal(order.quantity);
    if (quantity == null || total <= Decimal.zero) return '—';
    return (quantity * Decimal.fromInt(100) / total)
        .toDecimal(scaleOnInfinitePrecision: 4)
        .toStringAsFixed(2);
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells});
  final List<Widget> cells;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, cell) in cells.indexed) ...[
        if (index > 0) const SizedBox(width: 12),
        Expanded(child: cell),
      ],
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: const TextStyle(color: TradeColors.secondary),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
    style: TradeTypography.body,
  );
}

/// Size distribution explanation (design 10.11/10.12). The constant switch
/// only changes the illustrated curve; the form keeps its own selection.
Future<void> showScaledDistributionInfo(BuildContext context, {required ScaledConstant constant}) {
  final l10n = AppLocalizations.of(context);
  return showTradeContentSheet<void>(
    context,
    key: const Key('scaled-distribution-info'),
    title: l10n.scaledSizeDistribution,
    children: (_) => [_DistributionCards(initial: constant)],
  );
}

class _DistributionCards extends StatefulWidget {
  const _DistributionCards({required this.initial});
  final ScaledConstant initial;
  @override
  State<_DistributionCards> createState() => _DistributionCardsState();
}

class _DistributionCardsState extends State<_DistributionCards> {
  late var _increasing = widget.initial, _decreasing = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String ratio(ScaledConstant c, String name) => c == ScaledConstant.ratio ? '$name-ratio' : name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DistributionCard(title: l10n.scaledEqual, hint: l10n.scaledEqualHint, chart: 'equal'),
        _DistributionCard(
          title: l10n.scaledRandom,
          hint: l10n.scaledRandomHintShort,
          chart: 'random',
        ),
        _DistributionCard(
          title: l10n.scaledIncreasing,
          hint: l10n.scaledIncreasingHint,
          chart: ratio(_increasing, 'inc'),
          constant: _increasing,
          onConstant: (value) => setState(() => _increasing = value),
        ),
        _DistributionCard(
          title: l10n.scaledDecreasing,
          hint: l10n.scaledDecreasingHint,
          chart: ratio(_decreasing, 'dec'),
          constant: _decreasing,
          onConstant: (value) => setState(() => _decreasing = value),
        ),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.title,
    required this.hint,
    required this.chart,
    this.constant,
    this.onConstant,
  });
  final String title, hint, chart;
  final ScaledConstant? constant;
  final ValueChanged<ScaledConstant>? onConstant;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TradeTypography.section),
          if (constant case final selected?) ...[
            const SizedBox(height: 8),
            Container(
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: TradeColors.background,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  for (final (value, label) in [
                    (ScaledConstant.difference, l10n.scaledConstantDifference),
                    (ScaledConstant.ratio, l10n.scaledConstantRatio),
                  ]) ...[
                    if (value == ScaledConstant.ratio) const SizedBox(width: 4),
                    Expanded(
                      child: Semantics(
                        selected: value == selected,
                        button: true,
                        child: NoPressFeedback(
                          child: InkWell(
                            onTap: () => onConstant?.call(value),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: value == selected ? TradeColors.card : null,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TradeTypography.body.copyWith(
                                  color: value == selected
                                      ? TradeColors.text
                                      : TradeColors.secondary,
                                  fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(hint, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
          const SizedBox(height: 8),
          Container(
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TradeColors.sheet,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _Chart(chart),
          ),
        ],
      ),
    );
  }
}

/// Design chart art. The equal line is a 281.6 × 9.6 group placed inside the
/// same 320 × 56 frame as the other curves.
class _Chart extends StatelessWidget {
  const _Chart(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    final asset = 'assets/trade/scaled-chart-$name.svg';
    return FittedBox(
      child: SizedBox(
        width: 320,
        height: 56,
        child: name == 'equal'
            ? Center(child: SvgPicture.asset(asset, width: 281.6, height: 9.6))
            : SvgPicture.asset(asset, width: 320, height: 56),
      ),
    );
  }
}

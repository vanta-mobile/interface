import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/scaled_order.dart';
import 'scaled_order_options.dart';

class ScaledPlanDetails extends StatefulWidget {
  const ScaledPlanDetails({super.key, required this.plan, required this.data, this.clientIds});
  final ScaledOrderPlan plan;
  final LiveOrderContext data;
  final List<String>? clientIds;
  @override
  State<ScaledPlanDetails> createState() => _ScaledPlanDetailsState();
}

class _ScaledPlanDetailsState extends State<ScaledPlanDetails> {
  static const pageSize = 10;
  int page = 0;
  @override
  void didUpdateWidget(ScaledPlanDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.draft != widget.plan.draft) page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final start = page * pageSize, end = math.min(start + pageSize, plan.orders.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScaledPlanSummary(plan: plan, data: widget.data),
        for (var i = start; i < end; i++) ...[
          const Divider(),
          ScaledChildDetails(
            key: ValueKey('scaled-child-$i'),
            index: i,
            order: plan.orders[i],
            data: widget.data,
            total: plan.totalQuantity,
            clientId: widget.clientIds?[i],
          ),
        ],
        ScaledChildrenPager(
          prefix: 'scaled',
          page: page,
          size: pageSize,
          count: plan.orders.length,
          onChanged: (value) => setState(() => page = value),
        ),
      ],
    );
  }
}

class ScaledPlanSummary extends StatelessWidget {
  const ScaledPlanSummary({super.key, required this.plan, required this.data});
  final ScaledOrderPlan plan;
  final LiveOrderContext data;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), draft = plan.draft;
    final margin = data.leverage > 0
        ? (plan.notional / Decimal.fromInt(data.leverage)).toDecimal(scaleOnInfinitePrecision: 24)
        : null;
    final enteredAsset = draft.unit == ScaledSizeUnit.base
        ? data.rules.baseAsset
        : data.rules.quoteAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scaledPreview, style: Theme.of(context).textTheme.titleMedium),
        ValueRow(l10n.liveOrderSide, draft.buy ? l10n.long : l10n.short),
        ValueRow(l10n.scaledLow, '${draft.lowest} ${data.rules.quoteAsset}'),
        ValueRow(l10n.scaledHigh, '${draft.highest} ${data.rules.quoteAsset}'),
        ValueRow(l10n.scaledCount, '${draft.count}'),
        ValueRow(l10n.scaledEnteredSize, '${draft.quantity} $enteredAsset'),
        ValueRow(l10n.scaledDistribution, scaledDistributionLabel(l10n, draft.distribution)),
        if (draft.progressive)
          ValueRow(l10n.scaledConstant, scaledConstantLabel(l10n, draft.constant)),
        if (draft.distribution == ScaledDistribution.random)
          ValueRow(l10n.scaledVariance, '${draft.variance}%'),
        ValueRow(l10n.scaledTotalQuantity, '${plan.totalQuantity} ${data.rules.baseAsset}'),
        ValueRow(l10n.scaledTotalNotional, '${plan.notional} ${data.rules.quoteAsset}'),
        if (plan.unallocatedQuote case final remaining?) ...[
          ValueRow(l10n.scaledUnallocatedQuote, '$remaining ${data.rules.quoteAsset}'),
          Text(l10n.scaledAmountHint),
        ] else
          Text(l10n.scaledBaseRemainderHint),
        ValueRow(
          l10n.scaledMarginReference,
          margin == null ? '—' : '$margin ${data.rules.quoteAsset}',
        ),
        Text(l10n.scaledMarginHint),
      ],
    );
  }
}

class ScaledChildDetails extends StatelessWidget {
  const ScaledChildDetails({
    super.key,
    required this.index,
    required this.order,
    required this.data,
    required this.total,
    this.clientId,
  });
  final int index;
  final LiveOrderDraft order;
  final LiveOrderContext data;
  final Decimal total;
  final String? clientId;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), quantity = parseOrderDecimal(order.quantity)!;
    final percent = (quantity * Decimal.fromInt(100) / total).toDecimal(
      scaleOnInfinitePrecision: 4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scaledOrderNumber(index + 1)),
        ValueRow(l10n.scaledChildType, '${l10n.limit} · ${l10n.liveOrderPolicyGtc}'),
        ValueRow(l10n.liveOrderPrice(data.rules.quoteAsset), order.price),
        ValueRow(l10n.liveOrderQuantity(data.rules.baseAsset), order.quantity),
        ValueRow(l10n.scaledPortion, '$percent%'),
        ValueRow(
          l10n.liveOrderEstimatedNotional,
          '${quantity * parseOrderDecimal(order.price)!} ${data.rules.quoteAsset}',
        ),
        if (clientId != null) ...[Text(l10n.liveOrderClientId), SelectableText(clientId!)],
      ],
    );
  }
}

class ScaledChildrenPager extends StatelessWidget {
  const ScaledChildrenPager({
    super.key,
    required this.prefix,
    required this.page,
    required this.size,
    required this.count,
    required this.onChanged,
  });
  final String prefix;
  final int page, size, count;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    if (count <= size) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), end = math.min((page + 1) * size, count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scaledPage(page * size + 1, end, count)),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              key: ValueKey('$prefix-previous-children'),
              onPressed: page > 0 ? () => onChanged(page - 1) : null,
              child: Text(l10n.scaledPreviousChildren),
            ),
            OutlinedButton(
              key: ValueKey('$prefix-next-children'),
              onPressed: end < count ? () => onChanged(page + 1) : null,
              child: Text(l10n.scaledNextChildren),
            ),
          ],
        ),
      ],
    );
  }
}

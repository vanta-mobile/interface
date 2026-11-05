import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/scaled_order_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/scaled_order.dart';
import 'scaled_order_details.dart';
import 'scaled_order_options.dart';
import 'scaled_order_review.dart';

class ScaledOrderForm extends ConsumerStatefulWidget {
  const ScaledOrderForm({super.key, required this.data, required this.locked, required this.ready});
  final LiveOrderContext data;
  final bool locked, ready;
  @override
  ConsumerState<ScaledOrderForm> createState() => _ScaledOrderFormState();
}

class _ScaledOrderFormState extends ConsumerState<ScaledOrderForm> {
  final low = TextEditingController(),
      high = TextEditingController(),
      quantity = TextEditingController(),
      quote = TextEditingController(),
      count = TextEditingController(),
      variance = TextEditingController(text: '10');
  bool buy = true, reviewing = false;
  ScaledSizeUnit unit = ScaledSizeUnit.quote;
  ScaledDistribution distribution = ScaledDistribution.equal;
  ScaledConstant constant = ScaledConstant.difference;
  int? randomSeed;
  String? failure;
  @override
  void dispose() {
    low.dispose();
    high.dispose();
    quantity.dispose();
    quote.dispose();
    count.dispose();
    variance.dispose();
    super.dispose();
  }

  ScaledOrderDraft get draft => ScaledOrderDraft(
    buy: buy,
    lowest: low.text,
    highest: high.text,
    quantity: unit == ScaledSizeUnit.base ? quantity.text : quote.text,
    count: RegExp(r'^\d{1,3}$').hasMatch(count.text) ? int.parse(count.text) : 0,
    unit: unit,
    distribution: distribution,
    constant: constant,
    variance: variance.text,
    randomSeed: randomSeed,
  );
  void changed() => setState(() => failure = null);
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaledOrderPlan? plan;
    String? invalid;
    if (low.text.isNotEmpty &&
        high.text.isNotEmpty &&
        draft.quantity.isNotEmpty &&
        count.text.isNotEmpty) {
      try {
        plan = planScaledOrder(widget.data, draft);
      } on AccountReadFailure catch (error) {
        invalid = error.key;
      }
    }
    final enabled = !widget.locked && !reviewing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scaledRule),
        sideControls(l10n, enabled),
        inputs(l10n, enabled),
        if (failure ?? invalid case final key?)
          Text(
            tr(context, key),
            key: const Key('scaled-error'),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (plan != null) ScaledPlanDetails(plan: plan, data: widget.data),
        Text(l10n.scaledRisk),
        FilledButton(
          key: const Key('scaled-review'),
          onPressed: enabled && widget.ready && plan != null ? review : null,
          child: Text(l10n.scaledReview),
        ),
      ],
    );
  }

  Widget inputs(AppLocalizations l10n, bool enabled) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      input('scaled-low', l10n.scaledLow, widget.data.rules.quoteAsset, low, enabled),
      input('scaled-high', l10n.scaledHigh, widget.data.rules.quoteAsset, high, enabled),
      ScaledUnitControl(
        unit: unit,
        baseAsset: widget.data.rules.baseAsset,
        quoteAsset: widget.data.rules.quoteAsset,
        enabled: enabled,
        onChanged: (value) => setState(() {
          unit = value;
          failure = null;
        }),
      ),
      input(
        'scaled-quantity',
        unit == ScaledSizeUnit.base ? l10n.scaledTotalQuantity : l10n.scaledTotalAmount,
        unit == ScaledSizeUnit.base ? widget.data.rules.baseAsset : widget.data.rules.quoteAsset,
        unit == ScaledSizeUnit.base ? quantity : quote,
        enabled,
      ),
      input('scaled-count', l10n.scaledCount, l10n.scaledCountRange, count, enabled, integer: true),
      ScaledDistributionControl(
        distribution: distribution,
        constant: constant,
        enabled: enabled,
        onDistribution: (value) => setState(() {
          distribution = value;
          if (value == ScaledDistribution.random && randomSeed == null) reshuffle();
          failure = null;
        }),
        onConstant: (value) => setState(() {
          constant = value;
          failure = null;
        }),
      ),
      if (distribution == ScaledDistribution.random) ...[
        input('scaled-variance', l10n.scaledVariance, '%', variance, enabled),
        Text(l10n.scaledRandomHint),
        OutlinedButton(
          key: const Key('scaled-reshuffle'),
          onPressed: enabled
              ? () => setState(() {
                  reshuffle();
                  failure = null;
                })
              : null,
          child: Text(l10n.scaledReshuffle),
        ),
      ],
    ],
  );

  Widget sideControls(AppLocalizations l10n, bool enabled) => Wrap(
    spacing: 8,
    children: [
      ChoiceChip(
        key: const Key('scaled-buy'),
        label: Text(l10n.long),
        selected: buy,
        onSelected: enabled
            ? (_) => setState(() {
                buy = true;
                failure = null;
              })
            : null,
      ),
      ChoiceChip(
        key: const Key('scaled-sell'),
        label: Text(l10n.short),
        selected: !buy,
        onSelected: enabled
            ? (_) => setState(() {
                buy = false;
                failure = null;
              })
            : null,
      ),
    ],
  );

  void reshuffle() => randomSeed = ref.read(scaledOrderProvider.notifier).createRandomSeed();

  Widget input(
    String key,
    String label,
    String unit,
    TextEditingController controller,
    bool enabled, {
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      key: Key(key),
      controller: controller,
      enabled: enabled,
      onChanged: (_) => changed(),
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(labelText: '$label ($unit)'),
    ),
  );
  Future<void> review() async {
    final intent = ref.read(scaledOrderProvider.notifier).prepare(widget.data.symbol, draft);
    if (intent == null) {
      setState(() => failure = 'scaledRefreshRequired');
      return;
    }
    setState(() => reviewing = true);
    try {
      await reviewScaledOrder(context, ref, intent);
    } finally {
      if (mounted) setState(() => reviewing = false);
    }
  }
}

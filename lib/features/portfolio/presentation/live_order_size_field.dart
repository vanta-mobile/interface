import 'minimum_order_size_hint.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';

class LiveOrderSizeField extends StatelessWidget {
  const LiveOrderSizeField({
    super.key,
    required this.data,
    required this.pricingData,
    required this.draft,
    required this.unit,
    required this.controller,
    required this.enabled,
    required this.onUnit,
    required this.onInput,
  });
  final LiveOrderContext data;
  final LiveOrderContext? pricingData;
  final LiveOrderDraft draft;
  final OrderSizeUnit unit;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<OrderSizeUnit> onUnit;
  final VoidCallback onInput;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), rules = data.rules.quantityRule(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.liveAmountUnit, style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final choice in OrderSizeUnit.values)
              ChoiceChip(
                key: Key('live-order-unit-${choice.name}'),
                label: Text(
                  choice == OrderSizeUnit.quote ? data.rules.quoteAsset : data.rules.baseAsset,
                ),
                selected: choice == unit,
                onSelected: enabled ? (_) => onUnit(choice) : null,
              ),
          ],
        ),
        TextField(
          key: const Key('live-order-quantity'),
          controller: controller,
          readOnly: !enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: minimumOrderSizeHint(context, data: pricingData, draft: draft, unit: unit),
            labelText: unit == OrderSizeUnit.quote
                ? l10n.liveAmountInput(data.rules.quoteAsset)
                : l10n.liveOrderQuantity(data.rules.baseAsset),
            helperText: unit == OrderSizeUnit.quote
                ? l10n.liveAmountHint
                : l10n.liveOrderQuantityBounds(
                    '${rules.minimum}',
                    '${rules.maximum}',
                    '${rules.step}',
                  ),
            helperMaxLines: 4,
          ),
          onChanged: (_) => onInput(),
        ),
      ],
    );
  }
}

class LiveOrderSizePreview extends StatelessWidget {
  const LiveOrderSizePreview({super.key, required this.value, required this.data});
  final OrderSizeResolution value;
  final LiveOrderContext data;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!value.converted) return const SizedBox.shrink();
    final basis = switch (value.basis!) {
      OrderSizeReference.limit => l10n.liveAmountLimitReference,
      OrderSizeReference.ask => l10n.liveAmountAskReference,
      OrderSizeReference.bid => l10n.liveAmountBidReference,
      OrderSizeReference.trigger => l10n.liveAmountTriggerReference,
      OrderSizeReference.mark => l10n.openOrdersMarkPrice,
      OrderSizeReference.last => l10n.openOrdersLastPrice,
      OrderSizeReference.bboMark => l10n.liveAmountBboReference,
    };
    return Column(
      key: const Key('live-order-size-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          l10n.liveAmountInput(data.rules.quoteAsset),
          '${value.input} ${data.rules.quoteAsset}',
        ),
        ValueRow(
          l10n.liveAmountConversionPrice(basis),
          '${value.reference} ${data.rules.quoteAsset}',
        ),
        ValueRow(l10n.liveAmountResolvedQuantity, '${value.quantity} ${data.rules.baseAsset}'),
        ValueRow(
          l10n.liveOrderEstimatedNotional,
          '${value.estimatedNotional} ${data.rules.quoteAsset}',
        ),
        ValueRow(
          l10n.liveAmountSnapshotTime,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(value.referenceAt!.toUtc()),
        ),
        Text(l10n.liveAmountEstimateHint),
      ],
    );
  }
}

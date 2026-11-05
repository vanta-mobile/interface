import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/position_trigger_calculation.dart';

class LiveOrderTriggerCalculator extends StatefulWidget {
  const LiveOrderTriggerCalculator({
    super.key,
    required this.data,
    required this.draft,
    required this.enabled,
    required this.onApply,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final bool enabled;
  final ValueChanged<String> onApply;
  @override
  State<LiveOrderTriggerCalculator> createState() => _LiveOrderTriggerCalculatorState();
}

class _LiveOrderTriggerCalculatorState extends State<LiveOrderTriggerCalculator> {
  final input = TextEditingController();
  PositionTriggerInput mode = PositionTriggerInput.pnl;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), data = widget.data, draft = widget.draft;
    final quantity = data.referenceCloseQuantity(draft);
    final result = calculatePositionTriggerPrice(
      position: data.reductionPosition(draft),
      quantity: quantity,
      leverage: data.leverage,
      rules: data.rules,
      mode: mode,
      input: input.text.trim(),
    );
    return ExpansionTile(
      key: const Key('live-trigger-calculator'),
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.triggerCalculator),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.triggerCalculationHint),
            ValueRow(
              l10n.triggerCalculationQuantity,
              quantity == null ? '—' : '$quantity ${data.rules.baseAsset}',
            ),
            SegmentedButton<PositionTriggerInput>(
              key: const Key('live-trigger-calculation-mode'),
              segments: [
                ButtonSegment(
                  value: PositionTriggerInput.pnl,
                  label: Text(l10n.triggerCalculationPnlLabel),
                ),
                ButtonSegment(
                  value: PositionTriggerInput.roi,
                  label: Text(l10n.triggerCalculationRoi),
                ),
              ],
              selected: {mode},
              onSelectionChanged: widget.enabled
                  ? (value) => setState(() => mode = value.first)
                  : null,
            ),
            TextField(
              key: const Key('live-trigger-calculation-input'),
              controller: input,
              readOnly: !widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: mode == PositionTriggerInput.pnl
                    ? l10n.triggerCalculationPnl(data.rules.quoteAsset)
                    : l10n.triggerCalculationRoiTarget,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (result.price case final price?) ...[
              ValueRow(
                l10n.triggerCalculationPrice,
                '$price ${data.rules.quoteAsset}',
                key: const Key('live-trigger-calculated-price'),
              ),
              ValueRow(l10n.liveCloseEstimatedPnl, '${result.pnl} ${data.rules.quoteAsset}'),
              ValueRow(l10n.triggerCalculationRoi, '${result.roi}%'),
              Text(l10n.triggerCalculationRounding),
            ],
            if (input.text.isNotEmpty && result.failure != null) Text(tr(context, result.failure!)),
            OutlinedButton(
              key: const Key('live-trigger-calculation-apply'),
              onPressed: widget.enabled && result.price != null
                  ? () => widget.onApply(result.price.toString())
                  : null,
              child: Text(l10n.triggerCalculationApply),
            ),
          ],
        ),
      ],
    );
  }
}

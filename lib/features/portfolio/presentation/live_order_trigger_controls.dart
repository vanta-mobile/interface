import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';
import 'live_order_trigger_calculator.dart';
import 'live_order_trailing_controls.dart';

String liveOrderTypeLabel(AppLocalizations l10n, LiveOrderDraft draft) => draft.trailing != null
    ? l10n.openOrdersTrailingStop
    : switch ((draft.trigger?.kind, draft.market)) {
        (null, true) => l10n.market,
        (null, false) => l10n.limit,
        (LiveOrderTriggerKind.stop, true) => l10n.openOrdersStopMarket,
        (LiveOrderTriggerKind.stop, false) => l10n.openOrdersStopLimit,
        (LiveOrderTriggerKind.takeProfit, true) => l10n.openOrdersTakeProfitMarket,
        (LiveOrderTriggerKind.takeProfit, false) => l10n.openOrdersTakeProfitLimit,
      };

String _basisLabel(AppLocalizations l10n, LiveOrderTriggerBasis basis) =>
    basis == LiveOrderTriggerBasis.mark ? l10n.openOrdersMarkPrice : l10n.openOrdersLastPrice;

class LiveOrderTriggerControls extends StatelessWidget {
  const LiveOrderTriggerControls({
    super.key,
    required this.data,
    required this.draft,
    required this.price,
    required this.enabled,
    required this.onEnabled,
    required this.onKind,
    required this.onBasis,
    required this.onProtect,
    required this.onPrice,
    this.fixedConditional = false,
    this.showToggle = true,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final TextEditingController price;
  final bool enabled;
  final ValueChanged<bool> onEnabled, onProtect;
  final ValueChanged<LiveOrderTriggerKind> onKind;
  final ValueChanged<LiveOrderTriggerBasis> onBasis;
  final VoidCallback onPrice;
  final bool fixedConditional;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), trigger = draft.trigger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showToggle)
          SwitchListTile(
            key: const Key('live-order-conditional'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.liveOrderConditional),
            value: trigger != null,
            onChanged: enabled && !fixedConditional ? onEnabled : null,
          ),
        if (trigger != null) ...[
          SegmentedButton<LiveOrderTriggerKind>(
            key: const Key('live-order-trigger-kind'),
            segments: [
              ButtonSegment(value: LiveOrderTriggerKind.stop, label: Text(l10n.liveOrderStop)),
              ButtonSegment(
                value: LiveOrderTriggerKind.takeProfit,
                label: Text(l10n.liveOrderTakeProfit),
              ),
            ],
            selected: {trigger.kind},
            onSelectionChanged: enabled ? (value) => onKind(value.first) : null,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.liveOrderTriggerBasis),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LiveOrderTriggerBasis>(
                key: const Key('live-order-trigger-basis'),
                isExpanded: true,
                value: trigger.basis,
                items: [
                  for (final basis in LiveOrderTriggerBasis.values)
                    DropdownMenuItem(value: basis, child: Text(_basisLabel(l10n, basis))),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) onBasis(value);
                      }
                    : null,
              ),
            ),
          ),
          ValueRow(
            l10n.liveOrderTriggerReference,
            data.triggerReference(trigger) == null
                ? '—'
                : '${data.triggerReference(trigger)} ${data.rules.quoteAsset}',
          ),
          TextField(
            key: const Key('live-order-trigger-price'),
            controller: price,
            readOnly: !enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.openOrdersTriggerPrice,
              helperText: l10n.liveOrderPriceTick(data.rules.priceTick.toString()),
            ),
            onChanged: (_) => onPrice(),
          ),
          Text(trigger.rises(draft.buy) ? l10n.liveOrderTriggerRises : l10n.liveOrderTriggerFalls),
          if (draft.closingSide != null)
            LiveOrderTriggerCalculator(
              key: ValueKey((data.address.toLowerCase(), data.symbol, draft.closingSide)),
              data: data,
              draft: draft,
              enabled: enabled,
              onApply: (value) {
                price.text = value;
                onPrice();
              },
            ),
          SwitchListTile(
            key: const Key('live-order-trigger-protect'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.liveOrderTriggerProtect),
            value: trigger.protect,
            onChanged: enabled && (trigger.protect || data.rules.triggerProtect != null)
                ? onProtect
                : null,
          ),
          Text(l10n.liveOrderProtectHint),
          if (data.rules.triggerProtectPercent case final percent?)
            Text(l10n.liveOrderProtectThreshold(percent.toString())),
          Text(draft.entireClose ? l10n.liveEntireHint : l10n.liveOrderConditionalHint),
        ],
      ],
    );
  }
}

class LiveOrderTriggerSummary extends StatelessWidget {
  const LiveOrderTriggerSummary({super.key, required this.data, required this.draft});
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), trigger = draft.trigger;
    if (draft.trailing != null) return LiveOrderTrailingSummary(data: data, draft: draft);
    if (trigger == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderTriggerBasis, _basisLabel(l10n, trigger.basis)),
        ValueRow(
          l10n.openOrdersTriggerPrice,
          '${trigger.rises(draft.buy) ? '≥' : '≤'} ${trigger.price} ${data.rules.quoteAsset}',
        ),
        ValueRow(
          l10n.liveOrderTriggerProtect,
          trigger.protect ? l10n.liveOrderProtectOn : l10n.liveOrderProtectOff,
        ),
        Text(draft.entireClose ? l10n.liveEntireHint : l10n.liveOrderConditionalHint),
      ],
    );
  }
}

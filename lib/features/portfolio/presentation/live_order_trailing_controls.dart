import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';

class LiveOrderTrailingControls extends StatelessWidget {
  const LiveOrderTrailingControls({
    super.key,
    required this.data,
    required this.selected,
    required this.enabled,
    required this.rate,
    required this.activation,
    required this.basis,
    required this.onBasis,
    required this.onInput,
  });
  final LiveOrderContext data;
  final bool selected, enabled;
  final TextEditingController rate, activation;
  final LiveOrderTriggerBasis basis;
  final ValueChanged<LiveOrderTriggerBasis> onBasis;
  final VoidCallback onInput;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected) ...[
          Text(l10n.liveTrailingHint),
          TextField(
            key: const Key('live-trailing-rate'),
            controller: rate,
            readOnly: !enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.liveTrailingRate,
              helperText: l10n.liveTrailingRateBounds,
              helperMaxLines: 3,
            ),
            onChanged: (_) => onInput(),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.liveTrailingBasis),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LiveOrderTriggerBasis>(
                key: const Key('live-trailing-basis'),
                isExpanded: true,
                value: basis,
                items: [
                  for (final value in LiveOrderTriggerBasis.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == LiveOrderTriggerBasis.mark
                            ? l10n.openOrdersMarkPrice
                            : l10n.openOrdersLastPrice,
                      ),
                    ),
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
            '${basis == LiveOrderTriggerBasis.mark ? data.markPrice : data.lastPrice ?? '—'} ${data.rules.quoteAsset}',
          ),
          TextField(
            key: const Key('live-trailing-activation'),
            controller: activation,
            readOnly: !enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.liveTrailingActivation(data.rules.quoteAsset),
              helperText: l10n.liveTrailingDefault,
              helperMaxLines: 5,
            ),
            onChanged: (_) => onInput(),
          ),
          Text(l10n.liveTrailingActivationDirection),
        ],
      ],
    );
  }
}

class LiveOrderTrailingSummary extends StatelessWidget {
  const LiveOrderTrailingSummary({super.key, required this.data, required this.draft});
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), trailing = draft.trailing!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveTrailingRate, '${trailing.callbackRate}%'),
        ValueRow(
          l10n.liveTrailingBasis,
          trailing.basis == LiveOrderTriggerBasis.mark
              ? l10n.openOrdersMarkPrice
              : l10n.openOrdersLastPrice,
        ),
        if (trailing.activationPrice case final price?)
          ValueRow(l10n.liveTrailingActivation(data.rules.quoteAsset), price)
        else
          Text(l10n.liveTrailingDefault),
        Text(draft.buy ? l10n.liveTrailingBuy : l10n.liveTrailingSell),
        Text(l10n.liveTrailingEstimateHint),
      ],
    );
  }
}

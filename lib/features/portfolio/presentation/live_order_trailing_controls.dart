import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/live_order_draft.dart';
import '../domain/live_order_trigger.dart';
import 'live_order_embedded_inputs.dart';
import 'live_order_embedded_triggers.dart';
import '../../../core/presentation/no_press_feedback.dart';

/// Trailing stop inputs from the design: callback rate with its quick
/// presets, then the optional activation price with its price type.
class LiveOrderTrailingControls extends StatelessWidget {
  const LiveOrderTrailingControls({
    super.key,
    required this.enabled,
    required this.rate,
    required this.activation,
    required this.basis,
    required this.onBasis,
    required this.onInput,
  });
  final bool enabled;
  final TextEditingController rate, activation;
  final LiveOrderTriggerBasis basis;
  final ValueChanged<LiveOrderTriggerBasis> onBasis;
  final VoidCallback onInput;

  static final _presets = [Decimal.one, Decimal.fromInt(2)];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = parseOrderDecimal(rate.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbeddedInputBox(
          label: l10n.openOrdersCallbackRate,
          child: Row(
            children: [
              Expanded(
                child: EmbeddedTextInput(
                  fieldKey: const Key('live-trailing-rate'),
                  controller: rate,
                  enabled: enabled,
                  onChanged: onInput,
                ),
              ),
              Text('%', style: TradeTypography.body),
              const SizedBox(width: 8),
              for (final (i, preset) in _presets.indexed) ...[
                if (i > 0) Container(width: 1, height: 12, color: TradeColors.line),
                _RatePreset(
                  key: Key('live-trailing-rate-$preset'),
                  label: '$preset%',
                  selected: current == preset,
                  onTap: enabled
                      ? () {
                          rate.text = '$preset';
                          onInput();
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        EmbeddedInputBox(
          label: l10n.openOrdersActivationPrice,
          child: Row(
            children: [
              Expanded(
                child: EmbeddedTextInput(
                  fieldKey: const Key('live-trailing-activation'),
                  controller: activation,
                  enabled: enabled,
                  onChanged: onInput,
                ),
              ),
              TriggerBasisSelector(
                key: const Key('live-trailing-basis'),
                basis: basis,
                enabled: enabled,
                onChanged: onBasis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RatePreset extends StatelessWidget {
  const _RatePreset({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: NoPressFeedback(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TradeTypography.body.copyWith(
                  color: selected ? TradeColors.text : TradeColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

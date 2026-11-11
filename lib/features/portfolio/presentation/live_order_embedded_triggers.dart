import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../domain/attached_exit_input.dart';
import '../domain/live_order_trigger.dart';
import 'live_order_embedded_controls.dart';
import 'live_order_embedded_inputs.dart';

String triggerBasisLabel(AppLocalizations l, LiveOrderTriggerBasis basis) =>
    basis == LiveOrderTriggerBasis.mark ? l.openOrdersMarkPrice : l.openOrdersLastPrice;

Future<LiveOrderTriggerBasis?> showTriggerBasisSheet(
  BuildContext context,
  LiveOrderTriggerBasis selected,
) {
  final l = AppLocalizations.of(context);
  return showTradeOptionSheet(
    context,
    key: const Key('trigger-basis-sheet'),
    title: l.tradeSelectPriceType,
    selected: selected,
    options: [
      (
        value: LiveOrderTriggerBasis.last,
        label: l.openOrdersLastPrice,
        description: l.tradeTriggerByLast,
      ),
      (
        value: LiveOrderTriggerBasis.mark,
        label: l.openOrdersMarkPrice,
        description: l.tradeTriggerByMark,
      ),
    ],
  );
}

/// Price-type selector that opens the design sheet and reports the choice.
class TriggerBasisSelector extends StatelessWidget {
  const TriggerBasisSelector({
    super.key,
    required this.basis,
    required this.enabled,
    required this.onChanged,
    this.small = false,
  });
  final LiveOrderTriggerBasis basis;
  final bool enabled, small;
  final ValueChanged<LiveOrderTriggerBasis> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmbeddedSelector(
      label: triggerBasisLabel(l, basis),
      tooltip: l.tradeSelectPriceType,
      small: small,
      onTap: enabled
          ? () async {
              final value = await showTriggerBasisSheet(context, basis);
              if (value != null && value != basis) onChanged(value);
            }
          : null,
    );
  }
}

/// Stop/take-profit entry trigger price with its price type, as designed.
class EmbeddedTriggerField extends StatelessWidget {
  const EmbeddedTriggerField({
    super.key,
    required this.controller,
    required this.basis,
    required this.enabled,
    required this.onPrice,
    required this.onBasis,
  });
  final TextEditingController controller;
  final LiveOrderTriggerBasis basis;
  final bool enabled;
  final VoidCallback onPrice;
  final ValueChanged<LiveOrderTriggerBasis> onBasis;
  @override
  Widget build(BuildContext context) => EmbeddedInputBox(
    label: AppLocalizations.of(context).openOrdersTriggerPrice,
    child: Row(
      children: [
        Expanded(
          child: EmbeddedTextInput(
            fieldKey: const Key('live-order-trigger-price'),
            controller: controller,
            enabled: enabled,
            onChanged: onPrice,
          ),
        ),
        TriggerBasisSelector(
          key: const Key('live-order-trigger-basis'),
          basis: basis,
          enabled: enabled,
          onChanged: onBasis,
        ),
      ],
    ),
  );
}

String exitModeLabel(AppLocalizations l, AttachedExitInputMode mode, String asset) =>
    switch (mode) {
      AttachedExitInputMode.pnl => l.tradeExitPnl(asset),
      AttachedExitInputMode.price => l.tradeExitPrice(asset),
      AttachedExitInputMode.roi => l.tradeExitRoi,
    };

/// One TP or SL box: caption with price type, value input with input type.
class EmbeddedExitField extends StatelessWidget {
  const EmbeddedExitField({
    super.key,
    required this.kind,
    required this.controller,
    required this.mode,
    required this.basis,
    required this.asset,
    required this.enabled,
    required this.onValue,
    required this.onMode,
    required this.onBasis,
    this.issue,
  });
  final LiveOrderTriggerKind kind;
  final TextEditingController controller;
  final AttachedExitInputMode mode;
  final LiveOrderTriggerBasis basis;
  final String asset;
  final bool enabled;
  final VoidCallback onValue;
  final ValueChanged<AttachedExitInputMode> onMode;
  final ValueChanged<LiveOrderTriggerBasis> onBasis;
  final String? issue;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final takeProfit = kind == LiveOrderTriggerKind.takeProfit, name = takeProfit ? 'tp' : 'sl';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbeddedInputBox(
          label: takeProfit ? l.tradeTakeProfit : l.tradeStopLoss,
          labelTrailing: TriggerBasisSelector(
            key: Key('attached-$name-basis'),
            basis: basis,
            enabled: enabled,
            small: true,
            onChanged: onBasis,
          ),
          child: Row(
            children: [
              Expanded(
                child: EmbeddedTextInput(
                  fieldKey: Key('attached-$name-price'),
                  controller: controller,
                  enabled: enabled,
                  hint: takeProfit ? l.tradeTp : l.tradeSl,
                  signed: mode != AttachedExitInputMode.price,
                  onChanged: onValue,
                ),
              ),
              EmbeddedSelector(
                key: Key('attached-$name-mode'),
                label: exitModeLabel(l, mode, asset),
                tooltip: l.tradeSelectExitMode,
                onTap: enabled
                    ? () async {
                        final value = await showTradeOptionSheet(
                          context,
                          title: l.tradeSelectExitMode,
                          selected: mode,
                          options: [
                            for (final option in AttachedExitInputMode.values)
                              (
                                value: option,
                                label: exitModeLabel(l, option, asset),
                                description: null,
                              ),
                          ],
                        );
                        if (value != null && value != mode) onMode(value);
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (issue case final text?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: TradeTypography.small.copyWith(color: TradeColors.negative)),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import 'position_order_inputs.dart';
import '../domain/live_order_trigger.dart';
import '../domain/position_trigger_calculation.dart';

/// "Select Trigger Type" sheet: which price fires a TP/SL order.
Future<LiveOrderTriggerBasis?> showPositionTriggerTypeSheet(
  BuildContext context,
  LiveOrderTriggerBasis selected,
) {
  final l = AppLocalizations.of(context);
  return showTradeOptionSheet(
    context,
    key: const Key('position-tpsl-trigger-sheet'),
    title: l.positionTpslTriggerTitle,
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

/// "TP/SL Settings" sheet: whether the side box takes an estimated PnL or ROI.
Future<PositionTriggerInput?> showPositionTpSlSettingsSheet(
  BuildContext context,
  PositionTriggerInput selected,
  String asset,
) {
  final l = AppLocalizations.of(context);
  return showTradeOptionSheet(
    context,
    key: const Key('position-tpsl-settings-sheet'),
    title: l.positionTpslSettingsTitle,
    selected: selected,
    options: [
      (
        value: PositionTriggerInput.pnl,
        label: l.tradeExitPnl(asset),
        description: l.positionTpslPnlHint,
      ),
      (value: PositionTriggerInput.roi, label: l.tradeExitRoi, description: l.positionTpslRoiHint),
    ],
  );
}

/// Section title (14 px medium) with an optional inline control and a
/// trailing control such as "Limit order".
class PositionTpSlSectionHeader extends StatelessWidget {
  const PositionTpSlSectionHeader({super.key, required this.title, this.inline, this.trailing});
  final String title;
  final Widget? inline, trailing;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 20),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TradeTypography.body.copyWith(fontSize: 14, height: 20 / 14),
                ),
              ),
              if (inline != null) ...[const SizedBox(width: 8), inline!],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

/// The take-profit "trans" control that opens the trigger type sheet.
class PositionTriggerSwitch extends StatelessWidget {
  const PositionTriggerSwitch({super.key, required this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 16,
    child: OverflowBox(
      maxWidth: 44,
      maxHeight: 44,
      child: IconButton(
        tooltip: AppLocalizations.of(context).positionTpslSwitchBasis,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: const TradeIcon('position-trans', size: 16, color: TradeColors.text),
      ),
    ),
  );
}

/// Trigger price field joined to its 120 px estimated PnL/ROI field.
class PositionTriggerRow extends StatelessWidget {
  const PositionTriggerRow({
    super.key,
    required this.name,
    required this.priceLabel,
    required this.price,
    required this.priceSuffix,
    required this.estimateLabel,
    required this.estimate,
    required this.estimateSuffix,
    required this.enabled,
    required this.onPrice,
    required this.onEstimate,
    this.gap = 2,
  });
  final String name, priceLabel, estimateLabel;
  final TextEditingController price, estimate;
  final Widget priceSuffix, estimateSuffix;
  final bool enabled;
  final VoidCallback onPrice, onEstimate;
  final double gap;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PositionField(
            label: priceLabel,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: PositionValueInput(
              fieldKey: Key('position-tpsl-$name-price'),
              controller: price,
              enabled: enabled,
              onChanged: onPrice,
              suffix: priceSuffix,
            ),
          ),
        ),
        SizedBox(width: gap),
        SizedBox(
          width: 120,
          child: PositionField(
            label: estimateLabel,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            border: const Border(
              top: BorderSide(color: TradeColors.line),
              right: BorderSide(color: TradeColors.line),
              bottom: BorderSide(color: TradeColors.line),
            ),
            child: PositionValueInput(
              fieldKey: Key('position-tpsl-$name-estimate'),
              controller: estimate,
              enabled: enabled,
              signed: true,
              onChanged: onEstimate,
              suffix: estimateSuffix,
            ),
          ),
        ),
      ],
    ),
  );
}

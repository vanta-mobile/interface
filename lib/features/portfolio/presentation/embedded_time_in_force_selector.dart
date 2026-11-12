import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../domain/live_order_time_in_force.dart';
import 'mode_settings_sheet.dart';
import 'order_choice_sheet.dart';

/// The compact order form keeps Post Only in the order-type control and Hidden
/// in its checkbox. This sheet changes only the remaining time-in-force choice.
class EmbeddedTimeInForceSelector extends StatelessWidget {
  const EmbeddedTimeInForceSelector({
    super.key,
    required this.selected,
    required this.available,
    required this.onChanged,
    this.onTap,
  });
  final LiveOrderTimeInForce selected;
  final Set<LiveOrderTimeInForce> available;
  final ValueChanged<LiveOrderTimeInForce>? onChanged;

  /// Replaces the choice sheet, e.g. to connect an account first.
  final VoidCallback? onTap;

  Future<void> _select(BuildContext context) async {
    final value = await showModeSettingsSheet<LiveOrderTimeInForce>(
      context,
      _TimeInForceSheet(selected: selected, available: available),
    );
    if (value != null && context.mounted && available.contains(value)) onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null || onChanged != null,
    label: AppLocalizations.of(context).timeInForceTitle,
    value: selected.wire,
    child: Tooltip(
      message: AppLocalizations.of(context).timeInForceTitle,
      child: InkWell(
        onTap: onTap ?? (onChanged == null ? null : () => _select(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(selected.wire, style: TradeTypography.caption),
              const SizedBox(width: 4),
              SvgPicture.asset('assets/trade/policy-caret.svg'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimeInForceSheet extends StatelessWidget {
  const _TimeInForceSheet({required this.selected, required this.available});
  final LiveOrderTimeInForce selected;
  final Set<LiveOrderTimeInForce> available;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OrderChoiceSheet(
      key: const Key('time-in-force-sheet'),
      title: l.timeInForceTitle,
      children: [
        for (final policy in [LiveOrderTimeInForce.gtc, LiveOrderTimeInForce.ioc])
          if (available.contains(policy))
            TradeOptionRow(
              option: (
                value: policy,
                label: policy == LiveOrderTimeInForce.gtc ? l.timeInForceGtc : l.timeInForceIoc,
                description: null,
              ),
              selected: selected == policy,
              onTap: () => Navigator.pop(context, policy),
            ),
      ],
    );
  }
}

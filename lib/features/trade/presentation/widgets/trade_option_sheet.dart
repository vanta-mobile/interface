import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../portfolio/presentation/portfolio_components.dart';
import '../trade_theme.dart';
import 'trade_icon.dart';

typedef TradeOption<T> = ({T value, String label, String? description});

/// Single-choice action sheet from the Futures design (price type, units).
/// Resolves to the chosen value, or null when dismissed.
Future<T?> showTradeOptionSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<TradeOption<T>> options,
  Key? key,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: TradeColors.sheet,
  shape: const RoundedRectangleBorder(
    side: BorderSide(color: TradeColors.card),
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(child: Text(title, style: TradeTypography.heading)),
                IconButton(
                  tooltip: AppLocalizations.of(context).close,
                  onPressed: () => Navigator.pop(context),
                  icon: const PortfolioIcon('close.svg', size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: TradeColors.line),
          const SizedBox(height: 8),
          for (final option in options)
            _OptionRow(
              option: option,
              selected: option.value == selected,
              onTap: () => Navigator.pop(context, option.value),
            ),
        ],
      ),
    ),
  ),
);

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected, required this.onTap});
  final TradeOption<T> option;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      key: ValueKey('trade-option-${option.value}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TradeTypography.option.copyWith(
                        fontWeight: selected && option.description == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (option.description case final description?)
                      Text(
                        description,
                        style: TradeTypography.body.copyWith(
                          color: TradeColors.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? TradeColors.accent : null,
                  border: selected ? null : Border.all(color: TradeColors.muted),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: selected
                    ? const TradeIcon('check', size: 12, color: TradeColors.background)
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

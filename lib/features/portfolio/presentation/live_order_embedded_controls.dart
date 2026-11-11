import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';

/// Collapsed by default so optional order settings stay out of the main flow.
class EmbeddedAdvancedSection extends StatelessWidget {
  const EmbeddedAdvancedSection({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: TradeColors.transparent),
      child: ExpansionTile(
        key: const Key('live-order-advanced'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        minTileHeight: 32,
        iconColor: TradeColors.muted,
        collapsedIconColor: TradeColors.muted,
        title: Text(
          AppLocalizations.of(context).tradeAdvanced,
          style: TradeTypography.body.copyWith(color: TradeColors.secondary),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Design checkbox row: 11px box, white fill when selected, full-row target.
class EmbeddedCheckRow extends StatelessWidget {
  const EmbeddedCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Semantics(
            checked: value,
            enabled: enabled,
            child: InkWell(
              onTap: enabled ? () => onChanged!(!value) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: value ? TradeColors.text : TradeColors.card),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: value
                          ? Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: TradeColors.text,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: TradeTypography.caption.copyWith(
                          color: enabled ? TradeColors.text : TradeColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Small text-plus-caret control that opens a design option sheet.
class EmbeddedSelector extends StatelessWidget {
  const EmbeddedSelector({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });
  final String label, tooltip;
  final VoidCallback? onTap;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final style = (small ? TradeTypography.small : TradeTypography.body).copyWith(
      color: TradeColors.text,
    );
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: small ? 20 : 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.arrow_drop_down, size: small ? 14 : 18, color: TradeColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

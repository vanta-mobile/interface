import 'package:flutter/material.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../../trade/presentation/widgets/trade_option_sheet.dart';
import '../domain/live_order.dart';
import '../../../core/presentation/no_press_feedback.dart';

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
        minTileHeight: embeddedCheckRowHeight,
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

/// Row pitch of the design's Available / Advanced block (13px rows, 8px
/// gaps), shared by the Advanced rows with or without a trailing selector.
const embeddedCheckRowHeight = 21.0;

/// Design checkbox row: 11px box, white fill when selected, full-row target.
/// [help] adds the design question mark that opens an explanation sheet.
class EmbeddedCheckRow extends StatelessWidget {
  const EmbeddedCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.help,
    this.trailing,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? help;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: embeddedCheckRowHeight),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Semantics(
                    checked: value,
                    enabled: enabled,
                    child: NoPressFeedback(
                      child: InkWell(
                        onTap: enabled ? () => onChanged!(!value) : null,
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: value ? TradeColors.text : TradeColors.card,
                                  ),
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
                ),
                if (help case final help?) _HelpButton(title: label, message: help),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// 12px question mark with a 2px gap after the label; the tap target extends
/// vertically within the row so it stays usable without shifting the layout.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context).tradeOptionHelp(title),
    excludeSemantics: true,
    child: InkWell(
      key: ValueKey('trade-option-help-$title'),
      borderRadius: BorderRadius.circular(4),
      onTap: () => showTradeInfoSheet(context, title: title, message: message),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(2, 4, 6, 4),
        child: TradeIcon('question-mark', size: 12, color: TradeColors.muted),
      ),
    ),
  );
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

/// Available margin of the order form, with the deposit shortcut.
class EmbeddedAvailableRow extends StatelessWidget {
  const EmbeddedAvailableRow({super.key, required this.data});
  final LiveOrderContext data;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = data.funds?.account.availableBalance;
    // Value and deposit icon sit flush right with the design's 4px gap.
    return SizedBox(
      key: const Key('live-order-available'),
      height: embeddedCheckRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.available,
              style: TradeTypography.body.copyWith(color: TradeColors.secondary),
            ),
          ),
          Text(
            available == null
                ? '—'
                : '${TokenAmountFormatter.formatCompact(DecimalValue(available.toString()))} '
                      '${data.rules.quoteAsset}',
            style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.fundingDeposit,
            child: InkResponse(
              key: const Key('live-order-deposit'),
              radius: 16,
              onTap: () => openFunding(context, FundingOperation.deposit),
              child: const Icon(Icons.add_circle_outline, size: 12, color: TradeColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/trading_history.dart';
import 'futures_history_labels.dart';
import 'portfolio_components.dart';

const historyPlaceholder = '--';
String historyTime(DateTime? time, {bool compact = false}) => time == null
    ? historyPlaceholder
    : DateFormat(compact ? 'MM-dd HH:mm:ss' : 'yyyy-MM-dd HH:mm:ss').format(time.toLocal());
String historyAmount(Decimal? value, {int? fixed, bool signed = false}) {
  if (value == null) return historyPlaceholder;
  final text = fixed == null
      ? marketNumber(value)
      : TokenAmountFormatter.formatFixed(
          DecimalValue(value.toString()),
          decimals: value.scale > fixed ? value.scale : fixed,
          grouping: true,
        );
  return '${signed && value > Decimal.zero ? '+' : ''}$text';
}

String historyUnit(Decimal? value, String? unit, {int? fixed, bool signed = false}) => value == null
    ? historyPlaceholder
    : '${historyAmount(value, fixed: fixed, signed: signed)} ${unit ?? historyPlaceholder}';
Color historyPnlColor(Decimal? value) => value == null || value == Decimal.zero
    ? TradeColors.text
    : value > Decimal.zero
    ? TradeColors.positive
    : TradeColors.negative;

String historyRole(AppLocalizations l, bool? maker) => maker == null
    ? historyPlaceholder
    : maker
    ? l.historyMaker
    : l.historyTaker;

String historyTrigger(AppLocalizations l, HistoryOrder order) {
  final price = order.stopPrice;
  if (price == null || price <= Decimal.zero) return historyPlaceholder;
  final label = switch (order.workingType) {
    'MARK_PRICE' => l.openOrdersMarkPrice,
    'CONTRACT_PRICE' => l.openOrdersLastPrice,
    _ => null,
  };
  return '${historyAmount(price, fixed: 6)}${label == null ? '' : ' ($label)'}';
}

/// Hedge-mode position side identifies intent; one-way fills remain Buy/Sell.
String historyDirection(AppLocalizations l, String side, String? positionSide, {bool? reduceOnly}) {
  final buy = side == 'BUY';
  if (positionSide == 'LONG') return buy ? l.tradingHistoryOpenLong : l.tradingHistoryCloseLong;
  if (positionSide == 'SHORT') return buy ? l.tradingHistoryCloseShort : l.tradingHistoryOpenShort;
  if (reduceOnly == true) return buy ? l.tradingHistoryCloseShort : l.tradingHistoryCloseLong;
  return buy ? l.openOrdersBuy : l.openOrdersSell;
}

class HistoryRow extends StatelessWidget {
  const HistoryRow(this.label, this.value, {super.key, this.color, this.copyable = false});
  final String label, value;
  final Color? color;
  final bool copyable;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: copyable
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SelectableText(
                        value,
                        textAlign: TextAlign.end,
                        style: TradeTypography.body.copyWith(color: color),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('history-copy-$label'),
                      tooltip: '${MaterialLocalizations.of(context).copyButtonLabel} $label',
                      onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.topRight,
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: PortfolioIcon('history-copy.svg', size: 14),
                      ),
                    ),
                  ],
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TradeTypography.body.copyWith(color: color),
                ),
        ),
      ],
    ),
  );
}

class HistoryStatus extends StatelessWidget {
  const HistoryStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      'FILLED' => (TradeColors.positive, TradeColors.buyLabel),
      'PARTIALLY_FILLED' => (TradeColors.warning, TradeColors.warningLabel),
      'REJECTED' => (TradeColors.negative, TradeColors.sellLabel),
      _ => (TradeColors.text, TradeColors.card),
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        futuresHistoryStatus(AppLocalizations.of(context), status),
        style: TradeTypography.tag.copyWith(fontSize: 12, height: 1.5, color: foreground),
      ),
    );
  }
}

class HistoryTag extends StatelessWidget {
  const HistoryTag(this.label, {super.key, this.positive, this.outlined = false});
  final String label;
  final bool? positive;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: outlined
          ? null
          : positive == null
          ? TradeColors.card
          : positive!
          ? TradeColors.buyLabel
          : TradeColors.sellLabel,
      border: outlined ? Border.all(color: TradeColors.line) : null,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TradeTypography.tag.copyWith(
        color: positive == null
            ? TradeColors.secondary
            : positive!
            ? TradeColors.positive
            : TradeColors.negative,
      ),
    ),
  );
}

class HistoryExpand extends StatelessWidget {
  const HistoryExpand({super.key, required this.expanded});
  final bool expanded;
  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: expanded ? 3 : 1,
    child: PortfolioIcon(expanded ? 'history-collapse.svg' : 'history-expand.svg', size: 20),
  );
}

class HistorySheetHeader extends StatelessWidget {
  const HistorySheetHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: TradeTypography.heading)),
      IconButton(
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.pop(context),
        icon: const PortfolioIcon('history-close.svg', size: 24),
      ),
    ],
  );
}

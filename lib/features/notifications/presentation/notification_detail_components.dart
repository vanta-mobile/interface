import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/notification_status.dart';
import 'notification_tile.dart';

/// Event facts retain every decimal; these are historical values, not animated balances.
String notificationAmount(Decimal value, String? unit, AppLocalizations l, {bool signed = false}) {
  final amount = TokenAmountFormatter.format(
    DecimalValue(value.toString()),
    symbol: unit ?? l.accountUnitUnavailable,
    display: TokenAmountDisplay.exact,
  );
  return '${signed && value > Decimal.zero ? '+' : ''}$amount';
}

Color notificationPnlColor(Decimal value) => value < Decimal.zero
    ? NotificationColors.negative
    : value > Decimal.zero
    ? NotificationColors.positive
    : NotificationColors.detailValue;

class NotificationDetailHeader extends StatelessWidget {
  const NotificationDetailHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7, right: 16, bottom: 12),
    child: Row(
      children: [
        IconButton(
          key: const Key('notification-details-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
          icon: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: PortfolioIcon('notification-details-back.svg', size: 24),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(child: Text(title, style: NotificationTypography.heading)),
      ],
    ),
  );
}

class NotificationDetailCard extends StatelessWidget {
  const NotificationDetailCard({super.key, required this.children, this.spacing = 16});
  final List<Widget> children;
  final double spacing;
  @override
  Widget build(BuildContext context) => PortfolioCard(
    border: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing,
      children: children,
    ),
  );
}

class NotificationDetailSummary extends StatelessWidget {
  const NotificationDetailSummary({
    super.key,
    required this.title,
    required this.value,
    this.status,
    this.tone = NotificationTone.neutral,
  });
  final String title, value;
  final String? status;
  final NotificationTone tone;
  @override
  Widget build(BuildContext context) => NotificationDetailCard(
    key: const Key('notification-detail-summary'),
    spacing: 8,
    children: [
      Text(title, style: NotificationTypography.detailSummaryLabel),
      SelectableText(value, style: NotificationTypography.detailSummaryValue),
      if (status != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: notificationToneSurface(tone),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status!,
              style: NotificationTypography.detailStatus.copyWith(
                color: notificationToneColor(tone),
              ),
            ),
          ),
        ),
    ],
  );
}

class NotificationDetailRow extends StatelessWidget {
  const NotificationDetailRow(
    this.label,
    this.value, {
    super.key,
    this.copyable = false,
    this.color,
  });
  final String label, value;
  final bool copyable;
  final Color? color;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = SelectableText(
        value,
        textAlign: TextAlign.end,
        style: NotificationTypography.detailValue.copyWith(color: color),
      );
      final valueWidget = copyable
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: text),
                IconButton(
                  key: ValueKey('notification-copy-$label'),
                  tooltip: AppLocalizations.of(context).notificationCopyField(label),
                  onPressed: () => Clipboard.setData(ClipboardData(text: value)),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.topRight,
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: PortfolioIcon('notification-details-copy.svg', size: 14),
                  ),
                ),
              ],
            )
          : text;
      if (constraints.maxWidth < 250 || MediaQuery.textScalerOf(context).scale(12) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text(label, style: NotificationTypography.detailLabel),
            valueWidget,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: NotificationTypography.detailLabel)),
          const SizedBox(width: 12),
          Expanded(flex: 6, child: valueWidget),
        ],
      );
    },
  );
}

class NotificationDetailSection extends StatelessWidget {
  const NotificationDetailSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: NotificationTypography.detailSection);
}

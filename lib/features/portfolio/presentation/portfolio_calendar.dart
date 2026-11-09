import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';

class PortfolioCalendar extends StatelessWidget {
  const PortfolioCalendar({
    super.key,
    required this.month,
    required this.performance,
    required this.preview,
    required this.selectedDay,
    required this.onSelectedDay,
  });
  final DateTime month;
  final PortfolioPerformance performance;
  final bool preview;
  final int? selectedDay;
  final ValueChanged<int?> onSelectedDay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final firstWeekday = (month.weekday + 6) % 7;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final cells = ((firstWeekday + days + 6) ~/ 7) * 7;
    return PortfolioCard(
      radius: 20,
      border: false,
      child: Column(
        children: [
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: Text(
                    DateFormat.E(Localizations.localeOf(context).toLanguageTag())
                        .format(DateTime.utc(2026, 11, 2 + weekday)),
                    textAlign: TextAlign.center,
                    style: PortfolioTypography.caption,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var start = 0; start < cells; start += 7)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var offset = start; offset < start + 7; offset++)
                    Expanded(
                      child: _DayCell(
                        day: offset - firstWeekday + 1,
                        valid: offset >= firstWeekday && offset < firstWeekday + days,
                        month: month,
                        performance: performance,
                        preview: preview,
                        selected: selectedDay == offset - firstWeekday + 1,
                        onTap: () => onSelectedDay(offset - firstWeekday + 1),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l.portfolioCalendarNote, style: PortfolioTypography.caption),
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: 12),
            _SelectedDay(
              month: month,
              day: selectedDay!,
              performance: performance,
              preview: preview,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.valid,
    required this.month,
    required this.performance,
    required this.preview,
    required this.selected,
    required this.onTap,
  });
  final int day;
  final bool valid, preview, selected;
  final DateTime month;
  final PortfolioPerformance performance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cellHeight = 48.0 * MediaQuery.textScalerOf(context).scale(1);
    if (!valid) return SizedBox(height: cellHeight);
    final pnl = preview ? performance.dailyPnl[DateTime.utc(month.year, month.month, day)] : null;
    final color = portfolioPnlColor(pnl);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: cellHeight,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected ? PortfolioColors.button : null,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              maxLines: 1,
              softWrap: false,
              style: PortfolioTypography.caption.copyWith(color: PortfolioColors.text),
            ),
            Text(
              pnl == null ? '' : portfolioAmount(pnl),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: PortfolioTypography.navigation.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDay extends StatelessWidget {
  const _SelectedDay({
    required this.month,
    required this.day,
    required this.performance,
    required this.preview,
  });
  final DateTime month;
  final int day;
  final PortfolioPerformance performance;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), date = DateTime.utc(month.year, month.month, day);
    final value = preview ? performance.dailyPnl[date] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortfolioColors.inset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date),
            style: PortfolioTypography.caption,
          ),
          Text(
            value == null ? l.portfolioMissingDay : portfolioUsd(value, signed: true),
            style: PortfolioTypography.caption.copyWith(color: portfolioPnlColor(value)),
          ),
        ],
      ),
    );
  }
}

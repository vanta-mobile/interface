import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import '../application/portfolio_overview_provider.dart';
import '../../auth/application/auth_provider.dart';
import 'portfolio_history_chart.dart';
import 'portfolio_components.dart';
import 'portfolio_calendar.dart';

class PortfolioPnlScreen extends ConsumerStatefulWidget {
  const PortfolioPnlScreen({super.key});
  @override
  ConsumerState<PortfolioPnlScreen> createState() => _PortfolioPnlScreenState();
}

class _PortfolioPnlScreenState extends ConsumerState<PortfolioPnlScreen> {
  bool _calendar = false;
  String _period = '7D';
  late DateTime _month;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _month = ref.read(portfolioPreviewProvider)
        ? DateTime.utc(2026, 11)
        : DateTime.utc(now.year, now.month);
  }

  int? _day;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The overview provider supplies a preview only after explicit account selection.
    final overview = ref.watch(portfolioOverviewProvider);
    final preview = ref.watch(portfolioPreviewProvider);
    final identity = ref.watch(authProvider).identity;
    final performance = preview ? overview.performance : PortfolioPerformance();
    final daily = performance.dailyPnl.entries.where(
      (e) => e.key.year == _month.year && e.key.month == _month.month,
    );
    final monthPnl = daily.isEmpty ? null : daily.fold(Decimal.zero, (sum, e) => sum + e.value);
    final now = DateTime.now().toUtc();
    final latestMonth = preview ? DateTime.utc(2026, 11) : DateTime.utc(now.year, now.month);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final activeDay = _day == null
        ? null
        : preview
        ? performance.dailyPnl[DateTime.utc(_month.year, _month.month, _day!)]
        : null;
    final monthLabel = DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag())
        .format(_month);
    final identityLabel = preview
        ? l.portfolioPreviewAccount
        : identity?.walletAddress == null
        ? l.portfolioMainAccount
        : '${l.portfolioMainAccount} · ${_shortAddress(identity!.walletAddress!)}';
    return Scaffold(
      backgroundColor: PortfolioColors.background,
      appBar: AppBar(
        backgroundColor: PortfolioColors.background,
        surfaceTintColor: PortfolioColors.background,
        leading: IconButton(
          tooltip: l.backToTrade,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l.portfolioPnlDetails, style: PortfolioTypography.heading),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.watch(portfolioRefreshProvider),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth > 820
                  ? (constraints.maxWidth - 788) / 2
                  : 16.0;
              return ListView(
                key: const Key('portfolio-pnl-page'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 24),
                children: [
                  Row(
                    children: [
                      const PortfolioIcon('account.svg', color: PortfolioColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          identityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PortfolioTypography.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    key: const Key('portfolio-pnl-view'),
                    children: [
                      for (final (calendar, label) in [
                        (false, l.chart),
                        (true, l.portfolioCalendar),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Semantics(
                              selected: _calendar == calendar,
                              child: TextButton(
                                key: ValueKey('portfolio-pnl-view-$calendar'),
                                onPressed: () => setState(() {
                                  _calendar = calendar;
                                  _day = null;
                                }),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  backgroundColor: _calendar == calendar
                                      ? PortfolioColors.card
                                      : PortfolioColors.background,
                                  foregroundColor: _calendar == calendar
                                      ? PortfolioColors.accent
                                      : PortfolioColors.muted,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(label),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_calendar) ...[
                    Row(
                      children: [
                        IconButton(
                          key: const Key('portfolio-month-previous'),
                          tooltip: l.portfolioPreviousMonth,
                          onPressed: () => setState(() {
                            _month = DateTime.utc(_month.year, _month.month - 1);
                            _day = null;
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            style: PortfolioTypography.section,
                          ),
                        ),
                        IconButton(
                          key: const Key('portfolio-month-next'),
                          tooltip: l.portfolioNextMonth,
                          onPressed: !_month.isBefore(latestMonth)
                              ? null
                              : () => setState(() {
                                  _month = DateTime.utc(_month.year, _month.month + 1);
                                  _day = null;
                                }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PortfolioMetric(
                      label: l.portfolioMonthlyPnl,
                      value: monthPnl == null ? '—' : portfolioUsd(monthPnl, signed: true),
                      color: portfolioPnlColor(monthPnl),
                      large: true,
                    ),
                    if (activeDay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime.utc(_month.year, _month.month, _day!))} · ${portfolioUsd(activeDay, signed: true)}',
                          style: PortfolioTypography.body,
                        ),
                      ),
                    const SizedBox(height: 12),
                    PortfolioCalendar(
                      month: _month,
                      performance: performance,
                      preview: preview,
                      selectedDay: _day,
                      onSelectedDay: (day) => setState(() => _day = day),
                    ),
                  ] else ...[
                    Text(l.portfolioPnlPeriod(_period), style: PortfolioTypography.caption),
                    const SizedBox(height: 8),
                    PortfolioMetric(
                      label: '',
                      value: _period == '7D' && preview
                          ? portfolioUsd(performance.pnl, signed: true)
                          : '—',
                      note: _period == '7D' && preview
                          ? '${portfolioPercent(performance.returnPercent)} · ${DateFormat.MMMd(locale).format(performance.start!)} – ${DateFormat.MMMd(locale).format(performance.end!)}'
                          : null,
                      large: true,
                    ),
                    const SizedBox(height: 12),
                    PortfolioHistoryChart(
                      performance: performance,
                      period: _period,
                      unavailable: l.portfolioMissingPnl,
                    ),
                    const SizedBox(height: 8),
                    PortfolioPeriods(
                      selected: _period,
                      onChanged: (period) => setState(() => _period = period),
                    ),
                    const SizedBox(height: 12),
                    PortfolioCard(
                      radius: 14,
                      border: false,
                      child: Column(
                        children: [
                          _Detail(
                            label: l.portfolioVolumePeriod(_period),
                            value: _period == '7D' && preview
                                ? portfolioUsd(performance.volume)
                                : '—',
                          ),
                          const SizedBox(height: 12),
                          _Detail(
                            label: l.portfolioTodayPnl,
                            value: preview ? portfolioUsd(performance.todayPnl, signed: true) : '—',
                            color: portfolioPnlColor(preview ? performance.todayPnl : null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l.portfolioPnlNote, style: PortfolioTypography.caption),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.color = PortfolioColors.text});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: PortfolioTypography.caption)),
      Text(value, style: PortfolioTypography.caption.copyWith(color: color)),
    ],
  );
}

String _shortAddress(String address) => address.length < 13
    ? address
    : '${address.substring(0, 6)}…${address.substring(address.length - 4)}';

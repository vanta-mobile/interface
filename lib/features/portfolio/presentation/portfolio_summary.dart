import 'package:flutter/material.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/portfolio_stats_provider.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_stats_error.dart';
import 'portfolio_components.dart';
import 'portfolio_history_chart.dart';

class PortfolioAccountValue extends StatelessWidget {
  const PortfolioAccountValue({
    super.key,
    required this.overview,
    required this.stats,
    required this.visible,
    required this.active,
    required this.historyExpanded,
    required this.onToggleVisibility,
    required this.onToggleHistory,
    this.loading = false,
  });
  final PortfolioOverview overview;
  final PortfolioStatsView stats;
  final bool visible, active, historyExpanded, loading;
  final VoidCallback onToggleVisibility, onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = stats.performance;
    final total = visible ? portfolioUsd(overview.totalUsd) : '••••••';
    final today = visible
        ? '${portfolioUsd(p.todayPnl, signed: true)} (${portfolioPercent(p.todayPercent)})'
        : '••••';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: active ? 44 : 24,
          child: Row(
            children: [
              Expanded(child: Text(l.portfolioTotalValue, style: PortfolioTypography.caption)),
              if (active)
                IconButton(
                  key: const Key('portfolio-balance-visibility'),
                  tooltip: visible ? l.portfolioHideBalance : l.portfolioShowBalance,
                  onPressed: onToggleVisibility,
                  icon: visible
                      ? const PortfolioIcon('eye.svg', color: PortfolioColors.muted)
                      : const Icon(
                          Icons.visibility_off_outlined,
                          size: 20,
                          color: PortfolioColors.muted,
                        ),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final showSparkline =
                visible &&
                p.history.length >= 2 &&
                constraints.maxWidth >= 350 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.2;
            return Row(
              children: [
                Expanded(
                  child: loading && visible
                      ? Semantics(
                          label: l.accountReadLoading,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: SkeletonBox(
                              key: Key('portfolio-value-loading'),
                              width: 180,
                              height: 40,
                            ),
                          ),
                        )
                      : AnimatedNumberText(total, style: PortfolioTypography.value, softWrap: true),
                ),
                if (showSparkline)
                  Tooltip(
                    message: historyExpanded ? l.portfolioCollapseHistory : l.portfolioOpenHistory,
                    child: InkWell(
                      key: const Key('portfolio-value-history-toggle'),
                      onTap: onToggleHistory,
                      child: SizedBox(
                        height: 44,
                        child: Center(child: PortfolioHistoryChart(performance: p, compact: true)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        if (stats.loading && visible)
          Row(
            children: [
              Text(l.portfolioTodayPnl, style: PortfolioTypography.caption),
              const SizedBox(width: 6),
              const SkeletonBox(key: Key('portfolio-today-loading'), width: 96, height: 14),
            ],
          )
        else
          Text(
            '${l.portfolioTodayPnl} $today',
            style: PortfolioTypography.caption.copyWith(color: portfolioPnlColor(p.todayPnl)),
          ),
        if (visible &&
            p.history.length >= 2 &&
            (MediaQuery.sizeOf(context).width < 382 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2))
          TextButton(
            key: const Key('portfolio-value-history-text-toggle'),
            onPressed: onToggleHistory,
            child: Text(historyExpanded ? l.portfolioCollapseHistory : l.portfolioOpenHistory),
          ),
      ],
    );
  }
}

class PortfolioValueHistory extends StatelessWidget {
  const PortfolioValueHistory({
    super.key,
    required this.stats,
    required this.period,
    required this.onPeriod,
    required this.onCollapse,
  });
  final PortfolioStatsView stats;
  final String period;
  final ValueChanged<String> onPeriod;
  final VoidCallback onCollapse;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l.portfolioHistoryPeriod(period), style: PortfolioTypography.caption),
            ),
            IconButton(
              key: const Key('portfolio-value-history-collapse'),
              tooltip: l.portfolioCollapseHistory,
              onPressed: onCollapse,
              icon: const Icon(Icons.expand_less),
            ),
          ],
        ),
        if (stats.block != null && stats.block != PortfolioStatsBlock.unavailable)
          PortfolioCard(radius: 14, border: false, child: PortfolioStatsBlocked(stats))
        else
          PortfolioHistoryChart(
            performance: stats.performance,
            loading: stats.historyLoading,
            unavailable: l.portfolioMissingValue,
          ),
        PortfolioPeriods(selected: period, onChanged: onPeriod),
      ],
    );
  }
}

class PortfolioPerformanceCard extends StatelessWidget {
  const PortfolioPerformanceCard({
    super.key,
    required this.stats,
    required this.hidden,
    this.active = true,
  });
  final PortfolioStatsView stats;

  /// Signed-out pages keep their login entry; no statistics failure is shown.
  final bool hidden, active;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = stats.performance;
    // A build without the API keeps the placeholders here; PnL details explain it.
    if (active && stats.block != null && stats.block != PortfolioStatsBlock.unavailable) {
      return PortfolioCard(child: PortfolioStatsBlocked(stats));
    }
    final loading = stats.loading && !hidden;
    final metrics = [
      PortfolioMetric(
        label: l.portfolioPnl7d,
        value: hidden ? '••••' : portfolioUsd(p.pnl, signed: true),
        note: hidden ? '••••' : portfolioPercent(p.returnPercent),
        color: portfolioPnlColor(p.pnl),
        loading: loading,
        skeletonColor: StatusColors.skeletonOnCard,
      ),
      PortfolioMetric(
        label: l.portfolioVolume7d,
        value: hidden ? '••••' : portfolioUsd(p.volume),
        loading: loading,
        skeletonColor: StatusColors.skeletonOnCard,
      ),
    ];
    return PortfolioCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (MediaQuery.textScalerOf(context).scale(1) > 1.3 && constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [metrics[0], const SizedBox(height: 16), metrics[1]],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: metrics[0]),
              const SizedBox(width: 16),
              Expanded(child: metrics[1]),
            ],
          );
        },
      ),
    );
  }
}

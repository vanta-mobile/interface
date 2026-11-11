import 'package:flutter/material.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';
import 'portfolio_history_chart.dart';

class PortfolioAccountValue extends StatelessWidget {
  const PortfolioAccountValue({
    super.key,
    required this.overview,
    required this.visible,
    required this.active,
    required this.historyExpanded,
    required this.period,
    required this.onToggleVisibility,
    required this.onToggleHistory,
    this.loading = false,
  });
  final PortfolioOverview overview;
  final bool visible, active, historyExpanded, loading;
  final String period;
  final VoidCallback onToggleVisibility, onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = overview.performance;
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
        if (overview.partialValue && !loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.assetValueUnavailable, style: PortfolioTypography.caption),
          ),
        if (overview.staleValue)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.assetValueStale, style: PortfolioTypography.caption),
          ),
      ],
    );
  }
}

class PortfolioValueHistory extends StatelessWidget {
  const PortfolioValueHistory({
    super.key,
    required this.overview,
    required this.period,
    required this.onPeriod,
    required this.onCollapse,
  });
  final PortfolioOverview overview;
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
        PortfolioHistoryChart(
          performance: overview.performance,
          period: period,
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
    required this.overview,
    required this.preview,
    required this.hidden,
  });
  final PortfolioOverview overview;
  final bool preview, hidden;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = overview.performance;
    final metrics = [
      PortfolioMetric(
        label: l.portfolioPnl7d,
        value: hidden ? '••••' : portfolioUsd(p.pnl, signed: true),
        note: hidden ? '••••' : portfolioPercent(p.returnPercent),
        color: portfolioPnlColor(p.pnl),
      ),
      PortfolioMetric(label: l.portfolioVolume7d, value: hidden ? '••••' : portfolioUsd(p.volume)),
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

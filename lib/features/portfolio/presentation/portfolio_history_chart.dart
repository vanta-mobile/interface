import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';

const portfolioPeriods = ['24h', '7D', '14D', '30D', 'All'];

class PortfolioPeriods extends StatelessWidget {
  const PortfolioPeriods({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final period in portfolioPeriods)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              selected: selected == period,
              child: TextButton(
                key: ValueKey('portfolio-period-$period'),
                onPressed: () => onChanged(period),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: PortfolioColors.card,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    period == 'All' ? AppLocalizations.of(context).portfolioAll : period,
                    textAlign: TextAlign.center,
                    style: PortfolioTypography.caption.copyWith(
                      color: selected == period ? PortfolioColors.accent : PortfolioColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class PortfolioHistoryChart extends StatelessWidget {
  const PortfolioHistoryChart({
    super.key,
    required this.performance,
    this.compact = false,
    this.unavailable,
    this.loading = false,
  });

  /// [PortfolioPerformance.history] already belongs to the selected period.
  final PortfolioPerformance performance;
  final bool compact, loading;
  final String? unavailable;
  @override
  Widget build(BuildContext context) {
    final data = performance.history;
    final chart = SizedBox(
      height: compact ? 38 : 110,
      width: compact ? 112 : double.infinity,
      child: CustomPaint(
        painter: PortfolioHistoryPainter(
          data,
          compact: compact,
          buckets: performance.historyBuckets,
          breakBefore: performance.historyBreakBefore,
        ),
      ),
    );
    if (compact) return data.isEmpty ? const SizedBox.shrink() : chart;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return PortfolioCard(
      radius: 14,
      border: false,
      child: loading && data.isEmpty
          ? const SkeletonBox(
              key: Key('portfolio-history-loading'),
              height: 134,
              color: StatusColors.skeletonOnCard,
            )
          : data.length < 2 || performance.start == null || performance.end == null
          ? PortfolioEmpty(
              unavailable ?? AppLocalizations.of(context).portfolioMissingPnl,
              height: 134,
            )
          : Column(
              children: [
                chart,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      DateFormat.MMMd(locale).format(performance.start!),
                      style: PortfolioTypography.caption,
                    ),
                    const Spacer(),
                    Text(
                      DateFormat.MMMd(locale).format(performance.end!),
                      style: PortfolioTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Only chart coordinates cross into double; financial values stay Decimal.
class PortfolioHistoryPainter extends CustomPainter {
  PortfolioHistoryPainter(
    this.data, {
    required this.compact,
    this.buckets = const [],
    this.breakBefore = const {},
  });
  final List<DateTime> buckets;
  final Set<int> breakBefore;
  final List<Decimal> data;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final values = data.map((v) => v.toDouble()).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    final timed = buckets.length == values.length && buckets.last.isAfter(buckets.first);
    final duration = timed ? buckets.last.difference(buckets.first).inMicroseconds : 1;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          (timed
                  ? buckets[i].difference(buckets.first).inMicroseconds / duration
                  : i / (values.length - 1)) *
              size.width,
          size.height * .88 - (span == 0 ? .5 : (values[i] - min) / span) * size.height * .7,
        ),
    ];
    if (!compact) {
      final grid = Paint()
        ..color = PortfolioColors.line.withValues(alpha: .08)
        ..strokeWidth = 1;
      for (final fraction in [.2, .6, 1.0]) {
        canvas.drawLine(
          Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction),
          grid,
        );
      }
    }
    final starts = [
      0,
      ...breakBefore.where((i) => i > 0 && i < points.length).toList()..sort(),
      points.length,
    ];
    for (var segment = 1; segment < starts.length; segment++) {
      final first = starts[segment - 1], end = starts[segment];
      if (first == end) continue;
      final line = Path()..moveTo(points[first].dx, points[first].dy);
      for (var i = first + 1; i < end; i++) {
        final a = points[i - 1], b = points[i], mid = (a.dx + b.dx) / 2;
        line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }
      if (end - first == 1) {
        canvas.drawCircle(
          points[first],
          compact ? 1 : 1.7,
          Paint()..color = PortfolioColors.accent,
        );
        continue;
      }
      final area = Path.from(line)
        ..lineTo(points[end - 1].dx, size.height)
        ..lineTo(points[first].dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PortfolioColors.accent.withValues(alpha: .18),
              PortfolioColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = PortfolioColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1 : 1.7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(PortfolioHistoryPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.compact != compact ||
      oldDelegate.buckets != buckets ||
      oldDelegate.breakBefore != breakBefore;
}

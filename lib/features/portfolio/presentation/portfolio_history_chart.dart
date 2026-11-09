import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    this.period = '7D',
  });
  final PortfolioPerformance performance;
  final bool compact;
  final String? unavailable;
  final String period;
  @override
  Widget build(BuildContext context) {
    final data = period == '7D' ? performance.history : const <Decimal>[];
    final chart = SizedBox(
      height: compact ? 38 : 110,
      width: compact ? 112 : double.infinity,
      child: CustomPaint(painter: _HistoryPainter(data, compact: compact)),
    );
    if (compact) return data.isEmpty ? const SizedBox.shrink() : chart;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return PortfolioCard(
      radius: 14,
      border: false,
      child: data.isEmpty
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
class _HistoryPainter extends CustomPainter {
  _HistoryPainter(this.data, {required this.compact});
  final List<Decimal> data;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final values = data.map((v) => v.toDouble()).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          i * size.width / (values.length - 1),
          size.height * .88 - (span == 0 ? .5 : (values[i] - min) / span) * size.height * .7,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i], mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
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
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
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

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.compact != compact;
}

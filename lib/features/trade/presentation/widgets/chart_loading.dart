import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';

/// Non-blocking visual loading cue; the chart container keeps its dimensions.
class ChartLoading extends StatefulWidget {
  const ChartLoading({super.key, required this.interval, this.previousInterval});
  final String interval;
  final String? previousInterval;
  @override
  State<ChartLoading> createState() => _ChartLoadingState();
}

class _ChartLoadingState extends State<ChartLoading> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${tr(context, 'loadingChart')} ${widget.interval}',
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: MediaQuery.disableAnimationsOf(context)
                          ? .6
                          : .25 +
                                .75 *
                                    ((math.sin((_animation.value - i / 3) * math.pi * 2) + 1) / 2),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.previousInterval == null
                ? widget.interval
                : '${widget.previousInterval} → ${widget.interval}',
            style: const TextStyle(fontSize: 10, color: AppColors.secondary),
          ),
        ],
      ),
    ),
  );
}

class EmptyChartGrid extends StatelessWidget {
  const EmptyChartGrid({
    super.key,
    required this.mainHeight,
    required this.secondaryHeight,
    required this.panes,
  });
  final double mainHeight, secondaryHeight;
  final int panes;
  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('empty-chart-grid'),
    painter: _GridPainter(mainHeight, secondaryHeight, panes),
    child: const SizedBox.expand(),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.mainHeight, this.secondaryHeight, this.panes);
  final double mainHeight, secondaryHeight;
  final int panes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = .5;
    for (var x = 1; x < 5; x++) {
      canvas.drawLine(
        Offset(size.width * x / 5, 0),
        Offset(size.width * x / 5, size.height),
        paint,
      );
    }
    for (var y = 1; y <= 4; y++) {
      canvas.drawLine(Offset(0, mainHeight * y / 4), Offset(size.width, mainHeight * y / 4), paint);
    }
    for (var pane = 1; pane <= panes; pane++) {
      final y = (mainHeight + secondaryHeight * pane).clamp(0.0, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.mainHeight != mainHeight || old.secondaryHeight != secondaryHeight || old.panes != panes;
}

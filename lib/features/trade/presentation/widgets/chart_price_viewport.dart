import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../market/application/market_providers.dart';

import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import 'chart_canvas.dart';
import 'chart_loading.dart';

class ChartPriceViewport extends ConsumerWidget {
  const ChartPriceViewport({
    super.key,
    required this.market,
    required this.loading,
    required this.interval,
    required this.preferences,
    required this.mainHeight,
    required this.secondaryHeight,
  });
  final Market? market;
  final bool loading;
  final String interval;
  final ChartPreferences preferences;
  final double mainHeight, secondaryHeight;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    fit: StackFit.expand,
    children: [
      if (market case final market?)
        IgnorePointer(
          ignoring: loading,
          child: ExcludeSemantics(
            excluding: loading,
            child: Opacity(
              key: const Key('chart-visual'),
              opacity: loading ? .35 : 1,
              child: ChartCanvas(
                key: ValueKey('${market.symbol}/${market.interval}'),
                market: market,
                preferences: preferences,
                mainHeight: mainHeight,
                secondaryHeight: secondaryHeight,
                onLoadOlder: loading ? null : ref.read(chartHistoryProvider.notifier).loadOlder,
              ),
            ),
          ),
        )
      else
        EmptyChartGrid(
          mainHeight: mainHeight,
          secondaryHeight: secondaryHeight,
          panes: (preferences.volume ? 1 : 0) + (preferences.secondary != 'none' ? 1 : 0),
        ),
      if (loading)
        Center(
          child: ChartLoading(
            key: const Key('chart-loading'),
            interval: interval,
            previousInterval: market?.interval,
          ),
        ),
    ],
  );
}

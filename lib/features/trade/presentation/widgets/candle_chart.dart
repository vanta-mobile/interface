import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/market_failure.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import 'chart_price_viewport.dart';
import 'chart_axis_controls.dart';
import 'chart_market_status.dart';
import 'chart_toolbar.dart';
import 'depth_panel.dart';
import 'primitives.dart';

class CandleChart extends ConsumerStatefulWidget {
  const CandleChart({super.key, this.expanded = false, this.viewportHeight});
  final bool expanded;
  final double? viewportHeight;
  @override
  ConsumerState<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends ConsumerState<CandleChart> {
  Market? _lastChart;
  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(chartPreferencesProvider);
    final data = ref.watch(marketProvider);
    final interval = ref.watch(intervalProvider);
    final symbol = ref.watch(symbolProvider);
    final source = ref.watch(marketSyncProvider);
    final gap = source?.series.missingRange;
    final quote = ref.watch(currentMarketProvider);
    // A visual snapshot only. Never expose old data to prices or trading state.
    if (_lastChart?.symbol != symbol) _lastChart = null;
    if (quote != null) _lastChart = quote;
    final previous = _lastChart;
    final chartData = quote != null
        ? AsyncData<Market>(quote)
        : source?.failure != null
        ? AsyncError<Market>(MarketFailure(source!.failure!), StackTrace.empty)
        : !data.isLoading && data.hasError
        ? AsyncError<Market>(data.error!, data.stackTrace!)
        : const AsyncLoading<Market>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final secondaryHeight = wide ? 78.0 : 62.0;
        final extraHeight =
            (preferences.volume ? secondaryHeight : 0) +
            (preferences.secondary != 'none' ? secondaryHeight : 0) +
            (preferences.main == 'none' ? 0 : 12);
        final mainHeight = widget.expanded
            ? math.max(150.0, (widget.viewportHeight ?? 640) - 210 - extraHeight)
            : wide
            ? 300.0
            : 210.0;
        final canvasHeight = mainHeight + extraHeight;
        return Panel(
          child: Column(
            children: [
              ChartToolbar(
                depth: preferences.depth,
                onDepth: ref.read(chartPreferencesProvider.notifier).setDepth,
                expanded: widget.expanded,
                onExpand: () {
                  if (widget.expanded) {
                    Navigator.pop(context);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (context) => const ChartFullscreenPage()),
                    );
                  }
                },
              ),
              const Divider(),
              if (!preferences.depth) ...[const ChartTimeframes(), _CandleLegend(market: quote)],
              if (gap != null || quote?.failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    quote?.failure ?? tr(context, 'gap'),
                    style: const TextStyle(fontSize: 10, color: AppColors.warning),
                  ),
                ),
              SizedBox(
                key: const Key('chart-canvas-area'),
                height: preferences.depth ? mainHeight + secondaryHeight + 28 : canvasHeight,
                child: preferences.depth
                    ? const DepthCanvas()
                    : chartData.when(
                        skipLoadingOnRefresh: false,
                        data: (market) => ChartPriceViewport(
                          market: market,
                          loading: false,
                          interval: interval,
                          preferences: preferences,
                          mainHeight: mainHeight,
                          secondaryHeight: secondaryHeight,
                        ),
                        loading: () => ChartPriceViewport(
                          market: previous,
                          loading: true,
                          interval: interval,
                          preferences: preferences,
                          mainHeight: mainHeight,
                          secondaryHeight: secondaryHeight,
                        ),
                        error: (error, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error is MarketFailure
                                      ? error.message
                                      : tr(context, 'marketUnavailable'),
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () {
                                    final sync = ref.read(marketSyncProvider);
                                    if (sync == null) {
                                      ref.invalidate(instrumentsProvider);
                                    } else {
                                      sync.retry();
                                    }
                                    ref.invalidate(marketProvider);
                                  },
                                  child: Text(tr(context, 'retry')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const Divider(),
              if (!preferences.depth) const ChartAxisControls(),
              if (!preferences.depth) ...[const ChartIndicatorShortcuts(), const Divider()],
              ChartMarketStatus(depth: preferences.depth),
            ],
          ),
        );
      },
    );
  }
}

class _CandleLegend extends StatelessWidget {
  const _CandleLegend({required this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) {
    final candle = market?.candles.lastOrNull;
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final value in [
              ('open', candle?.open),
              ('candleHigh', candle?.high),
              ('candleLow', candle?.low),
              ('candleClose', candle?.close),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${tr(context, value.$1)} ',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(
                        text: value.$2 == null
                            ? '—'
                            : marketNumber(
                                value.$2!,
                                minimumDecimals: market?.precision.priceDecimals ?? 0,
                              ),
                        style: TextStyle(
                          color: candle == null
                              ? AppColors.secondary
                              : candle.close >= candle.open
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 9, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChartFullscreenPage extends ConsumerWidget {
  const ChartFullscreenPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${ref.watch(symbolProvider).replaceAll('USDT', '')} / USDT',
        style: const TextStyle(fontSize: 16),
      ),
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: CandleChart(expanded: true, viewportHeight: constraints.maxHeight),
        ),
      ),
    ),
  );
}

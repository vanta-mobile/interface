import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'chart_controls.dart';
import 'chart_price_viewport.dart';

/// Full-bleed compact K-line toggled from the order book column (Figma 12.01).
/// It shares the chart's market feed, interval and display preferences; it
/// does not open another stream.
class TradeKlinePanel extends ConsumerWidget {
  const TradeKlinePanel({super.key});

  static const _row = 36.0, _ohlc = 24.0, _indicators = 32.0;
  static const _mainHeight = 164.0, _paneHeight = 62.0, _legendHeight = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(intervalProvider);
    final preferences = ref.watch(chartPreferencesProvider);
    final market = ref.watch(currentMarketProvider);
    final loading = ref.watch(marketProvider).isLoading;
    final canvasHeight =
        _mainHeight +
        (preferences.volume ? _paneHeight : 0) +
        (preferences.secondary != 'none' ? _paneHeight : 0) +
        (preferences.main == 'none' ? 0 : _legendHeight);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('trade-kline'),
        // Two 1px borders plus the fixed rows around the canvas.
        height: 2 + _row + _ohlc + canvasHeight + _indicators + _row,
        child: OverflowBox(
          // Bleed past the workspace's 16px gutters, as designed.
          minWidth: constraints.maxWidth + 32,
          maxWidth: constraints.maxWidth + 32,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: TradeColors.switchBackground,
              border: Border.symmetric(horizontal: BorderSide(color: TradeColors.line)),
            ),
            child: Column(
              children: [
                const SizedBox(height: _row - 1, child: ChartTimeframeRow()),
                const Divider(height: 1, thickness: 1, color: TradeColors.line),
                SizedBox(
                  height: _ohlc,
                  child: ChartOhlcRow(market: market),
                ),
                SizedBox(
                  key: const Key('trade-kline-canvas'),
                  height: canvasHeight,
                  child: ChartPriceViewport(
                    market: market,
                    loading: loading && market == null,
                    interval: interval,
                    preferences: preferences,
                    mainHeight: _mainHeight,
                    secondaryHeight: _paneHeight,
                  ),
                ),
                const SizedBox(height: _indicators, child: ChartIndicatorRow()),
                const SizedBox(height: _row, child: ChartActionBar()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

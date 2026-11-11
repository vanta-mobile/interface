import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'chart_price_viewport.dart';

const _klineIntervals = ['1m', '3m', '5m', '15m', '30m', '1h'];

/// Full-bleed compact K-line toggled from the order book column. It shares
/// the chart's market feed and interval; it does not open another stream.
class TradeKlinePanel extends ConsumerWidget {
  const TradeKlinePanel({super.key});

  static const _height = 200.0, _timeframes = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(intervalProvider);
    final preferences = ref.watch(chartPreferencesProvider);
    final line = preferences.chartType == KChartType.line;
    final market = ref.watch(currentMarketProvider);
    final loading = ref.watch(marketProvider).isLoading;
    final chart = preferences.copyWith(main: 'MA', secondary: 'none', volume: false, depth: false);
    void select(String value, {required bool asLine}) {
      ref.read(chartPreferencesProvider.notifier).setLine(asLine);
      ref.read(intervalProvider.notifier).select(value);
    }

    Widget option(String label, {required bool selected, required VoidCallback onTap}) => Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('trade-kline-$label'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TradeTypography.caption.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? TradeColors.text : TradeColors.muted,
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('trade-kline'),
        height: _height,
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
                SizedBox(
                  height: _timeframes - 1,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    children: [
                      option(
                        tr(context, 'time'),
                        selected: line,
                        onTap: () => select('1m', asLine: true),
                      ),
                      for (final value in _klineIntervals)
                        option(
                          value,
                          selected: !line && value == interval,
                          onTap: () => select(value, asLine: false),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: TradeColors.line),
                Expanded(
                  child: ChartPriceViewport(
                    market: market,
                    loading: loading && market == null,
                    interval: interval,
                    preferences: chart,
                    mainHeight: _height - _timeframes - 2,
                    secondaryHeight: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

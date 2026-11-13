import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../market/domain/candle_interval.dart';
import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'candle_chart.dart';
import 'chart_indicator_sheet.dart';
import 'chart_settings_sheets.dart';
import 'trade_icon.dart';

// Rows of the Figma `chart` component (12.01 / 12.08). Each fills the height
// its parent gives it, so the K-line tab and the trade-page panel can use the
// sizes of their own frames.

/// Lays [children] out edge to edge like the design, scrolling only when
/// enlarged text no longer fits the row.
class _SpreadRow extends StatelessWidget {
  const _SpreadRow({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth - 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: children),
      ),
    ),
  );
}

class _RowOption extends StatelessWidget {
  const _RowOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor, color;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TradeTypography.caption.copyWith(color: selected ? selectedColor : color),
        ),
      ),
    ),
  );
}

/// 1m 5m 15m 1h 4h 1d More▾. More opens the timeframe sheet (12.03).
class ChartTimeframeRow extends ConsumerWidget {
  const ChartTimeframeRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(intervalProvider);
    final quick = quickCandleIntervals.contains(interval);
    return _SpreadRow(
      children: [
        for (final value in quickCandleIntervals)
          _RowOption(
            key: Key('timeframe-$value'),
            label: value,
            selected: value == interval,
            selectedColor: TradeColors.text,
            color: TradeColors.muted,
            onTap: () => ref.read(intervalProvider.notifier).select(value),
          ),
        _RowOption(
          key: const Key('chart-more-timeframes'),
          // A longer interval picked from the sheet takes the More slot.
          label: '${quick ? tr(context, 'more') : interval} ▾',
          selected: !quick,
          selectedColor: TradeColors.text,
          color: TradeColors.muted,
          onTap: () => showChartTimeframeSheet(context, ref),
        ),
      ],
    );
  }
}

/// O H L C of the latest candle, values colored by its direction.
class ChartOhlcRow extends StatelessWidget {
  const ChartOhlcRow({super.key, required this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) {
    final candle = market?.candles.lastOrNull;
    final color = candle == null
        ? TradeColors.muted
        : candle.close >= candle.open
        ? TradeColors.positive
        : TradeColors.negative;
    final style = TradeTypography.small.copyWith(
      color: TradeColors.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SingleChildScrollView(
      key: const Key('chart-ohlc'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (final (index, entry) in [
                  ('open', candle?.open),
                  ('candleHigh', candle?.high),
                  ('candleLow', candle?.low),
                  ('candleClose', candle?.close),
                ].indexed) ...[
                  TextSpan(text: '${index == 0 ? '' : '  '}${tr(context, entry.$1)} '),
                  TextSpan(
                    text: entry.$2 == null
                        ? '—'
                        : marketNumber(
                            entry.$2!,
                            minimumDecimals: market?.precision.priceDecimals ?? 0,
                          ),
                    style: TextStyle(color: color),
                  ),
                ],
              ],
            ),
            style: style,
          ),
        ],
      ),
    );
  }
}

/// MA BOLL VOL MACD KDJ RSI WR CCI shortcuts.
class ChartIndicatorRow extends ConsumerWidget {
  const ChartIndicatorRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(chartPreferencesProvider);
    return _SpreadRow(
      children: [
        for (final value in indicatorShortcuts)
          _RowOption(
            key: Key('chart-quick-$value'),
            label: value,
            selected: preferences.shows(value),
            selectedColor: TradeColors.positive,
            color: TradeColors.text,
            onTap: () => ref.read(chartPreferencesProvider.notifier).toggle(value),
          ),
      ],
    );
  }
}

/// Price scale (12.04), chart type (12.02), indicators (12.05), fullscreen.
class ChartActionBar extends ConsumerWidget {
  const ChartActionBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(chartPreferencesProvider.select((p) => p.priceScale));
    Widget action(String key, String tooltip, Widget icon, VoidCallback onPressed) => IconButton(
      key: Key(key),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: icon,
    );
    return ColoredBox(
      color: TradeColors.card,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: const Key('chart-price-scale'),
                onTap: () => showChartPriceScaleSheet(context, ref),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${tr(context, 'priceScale')}: ${tr(context, 'scale-${scale.name}')}',
                          overflow: TextOverflow.ellipsis,
                          style: TradeTypography.body.copyWith(color: TradeColors.muted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const TradeIcon('chart-caret', size: 6, color: TradeColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 36px targets keep the designed 12px gap between the 24px icons.
          action(
            'chart-type',
            tr(context, 'chartType'),
            const TradeIcon('chart-style', size: 18, color: TradeColors.muted),
            () => showChartTypeSheet(context, ref),
          ),
          action(
            'chart-indicators',
            tr(context, 'indicators'),
            const TradeIcon('chart-indicators', size: 24, color: TradeColors.muted),
            () => showChartIndicatorSheet(context),
          ),
          action(
            'chart-expand',
            tr(context, 'fullscreen'),
            const TradeIcon('chart-fullscreen', size: 20, color: TradeColors.muted),
            () => openChartFullscreen(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/domain/candle_series.dart';
import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import 'chart_indicator_sheet.dart';
import 'primitives.dart';

class ChartToolbar extends ConsumerWidget {
  const ChartToolbar({
    super.key,
    required this.depth,
    required this.onDepth,
    required this.onExpand,
    required this.expanded,
  });
  final bool depth, expanded;
  final ValueChanged<bool> onDepth;
  final VoidCallback onExpand;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(chartPreferencesProvider);
    return Row(
      children: [
        Expanded(
          child: TabChoices(
            items: [tr(context, 'chart'), tr(context, 'depth')],
            selected: depth ? 1 : 0,
            onSelect: (index) => onDepth(index == 1),
            underlined: true,
          ),
        ),
        if (!depth) ...[
          PopupMenuButton<KChartType>(
            key: const Key('chart-type'),
            tooltip: tr(context, 'chartType'),
            icon: Icon(
              preferences.line
                  ? Icons.stacked_line_chart_rounded
                  : Icons.candlestick_chart_outlined,
              size: 19,
            ),
            onSelected: ref.read(chartPreferencesProvider.notifier).setChartType,
            itemBuilder: (context) => [
              for (final type in KChartType.values)
                CheckedPopupMenuItem(
                  key: ValueKey('chart-type-${type.name}'),
                  value: type,
                  checked: preferences.chartType == type,
                  child: Text(tr(context, 'type-${type.name}')),
                ),
            ],
          ),
          IconButton(
            key: const Key('chart-indicators'),
            tooltip: tr(context, 'indicators'),
            onPressed: () => showAppSheet<void>(context, const ChartIndicatorSheet()),
            icon: const Icon(Icons.functions_rounded, size: 19),
          ),
        ],
        IconButton(
          key: const Key('chart-expand'),
          tooltip: tr(context, expanded ? 'exitFullscreen' : 'fullscreen'),
          onPressed: onExpand,
          icon: Icon(
            expanded ? Icons.close_fullscreen_rounded : Icons.fullscreen_rounded,
            size: 21,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class ChartTimeframes extends ConsumerWidget {
  const ChartTimeframes({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(intervalProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (final value in quickCandleIntervals)
            Semantics(
              selected: value == interval,
              button: true,
              child: InkWell(
                key: Key('timeframe-$value'),
                onTap: () => ref.read(intervalProvider.notifier).select(value),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 46),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: value == interval ? AppColors.raised : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 11,
                        color: value == interval ? AppColors.text : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            key: const Key('chart-more-timeframes'),
            tooltip: tr(context, 'moreTimeframes'),
            initialValue: interval,
            onSelected: ref.read(intervalProvider.notifier).select,
            itemBuilder: (context) => [
              for (final value in candleIntervals)
                CheckedPopupMenuItem(
                  key: ValueKey('timeframe-option-$value'),
                  value: value,
                  checked: value == interval,
                  child: Text(value),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                '${quickCandleIntervals.contains(interval) ? tr(context, 'more') : interval} ▾',
                style: const TextStyle(fontSize: 11, color: AppColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartIndicatorShortcuts extends ConsumerWidget {
  const ChartIndicatorShortcuts({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(chartPreferencesProvider);
    final controller = ref.read(chartPreferencesProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          for (final value in ['MA', 'BOLL', 'VOL', 'MACD', 'KDJ', 'RSI', 'WR', 'CCI'])
            Builder(
              builder: (context) {
                final selected = value == 'VOL'
                    ? preferences.volume
                    : ['MA', 'BOLL'].contains(value)
                    ? preferences.main == value
                    : preferences.secondary == value;
                return Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: Key('chart-quick-$value'),
                    onTap: () {
                      if (value == 'VOL') {
                        controller.setVolume(!preferences.volume);
                      } else if (['MA', 'BOLL'].contains(value)) {
                        controller.setMain(selected ? 'none' : value);
                      } else {
                        controller.setSecondary(selected ? 'none' : value);
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44, minWidth: 46),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? AppColors.accent : AppColors.muted,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

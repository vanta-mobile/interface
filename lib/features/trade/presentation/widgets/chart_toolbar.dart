import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/domain/candle_series.dart';
import '../../application/providers.dart';

/// Timeframe row; [trailing] holds the fullscreen entry or exit, as designed.
class ChartTimeframes extends ConsumerWidget {
  const ChartTimeframes({super.key, this.trailing});
  final Widget? trailing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(intervalProvider);
    final row = SingleChildScrollView(
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
    if (trailing == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        trailing!,
      ],
    );
  }
}

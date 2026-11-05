import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/application/market_providers.dart';
import '../../application/chart_preferences.dart';

class ChartAxisControls extends ConsumerWidget {
  const ChartAxisControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chartPreferencesProvider.select((p) => p.priceScale));
    final market = ref.watch(currentMarketProvider);
    final heikin = ref.watch(
      chartPreferencesProvider.select((p) => p.chartType == KChartType.heikinAshi),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PopupMenuButton<KPriceScale>(
                key: const Key('chart-price-scale'),
                tooltip: tr(context, 'priceScale'),
                initialValue: mode,
                onSelected: ref.read(chartPreferencesProvider.notifier).setPriceScale,
                itemBuilder: (context) => [
                  for (final value in KPriceScale.values)
                    CheckedPopupMenuItem(
                      value: value,
                      checked: value == mode,
                      child: Text(tr(context, 'scale-${value.name}')),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(
                    '${tr(context, 'priceScale')}: ${tr(context, 'scale-${mode.name}')} ▾',
                    style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                  ),
                ),
              ),
            ),
            if (market?.historyLoading == true || market?.historyExhausted == true)
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(
                      tr(context, market!.historyLoading ? 'loadingHistory' : 'historyEnd'),
                      style: const TextStyle(fontSize: 10, color: AppColors.secondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (market?.historyFailure != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: ref.read(chartHistoryProvider.notifier).loadOlder,
              child: Text(
                '${market!.historyFailure} · ${tr(context, 'retry')}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        if (heikin || mode == KPriceScale.percentage || mode == KPriceScale.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              tr(context, heikin ? 'heikinAshiHint' : 'relativeScaleHint'),
              style: const TextStyle(fontSize: 9, color: AppColors.secondary),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/domain/candle_interval.dart';
import '../../../portfolio/presentation/mode_settings_sheet.dart';
import '../../application/chart_preferences.dart';
import '../../application/providers.dart';
import 'trade_option_sheet.dart';

/// Chart settings list sheets (Figma 12.02–12.04): one choice, applied on tap.
Future<T?> _showChartChoice<T>(
  BuildContext context, {
  required Key key,
  required String title,
  required T selected,
  required List<TradeOption<T>> options,
}) => showModeSettingsSheet<T>(
  context,
  Builder(
    builder: (context) => ModeSheetBody(
      key: key,
      title: title,
      children: [
        for (final option in options)
          TradeOptionRow(
            option: option,
            selected: option.value == selected,
            emphasizeSelected: false,
            unselectedMark: false,
            onTap: () => Navigator.pop(context, option.value),
          ),
      ],
    ),
  ),
);

Future<void> showChartTypeSheet(BuildContext context, WidgetRef ref) async {
  final value = await _showChartChoice(
    context,
    key: const Key('chart-type-sheet'),
    title: tr(context, 'chartType'),
    selected: ref.read(chartPreferencesProvider).chartType,
    options: [
      for (final type in KChartType.values)
        (value: type, label: tr(context, 'type-${type.name}'), description: null),
    ],
  );
  if (value != null) ref.read(chartPreferencesProvider.notifier).setChartType(value);
}

Future<void> showChartTimeframeSheet(BuildContext context, WidgetRef ref) async {
  final value = await _showChartChoice(
    context,
    key: const Key('chart-timeframe-sheet'),
    title: AppLocalizations.of(context).chartSelectTimeframe,
    selected: ref.read(intervalProvider),
    options: [
      for (final interval in candleIntervals) (value: interval, label: interval, description: null),
    ],
  );
  if (value != null) ref.read(intervalProvider.notifier).select(value);
}

Future<void> showChartPriceScaleSheet(BuildContext context, WidgetRef ref) async {
  final value = await _showChartChoice(
    context,
    key: const Key('chart-price-scale-sheet'),
    title: tr(context, 'priceScale'),
    selected: ref.read(chartPreferencesProvider).priceScale,
    options: [
      for (final scale in KPriceScale.values)
        (
          value: scale,
          label: tr(context, 'scale-${scale.name}'),
          // Relative axes explain their reference bar, as designed.
          description: scale == KPriceScale.percentage || scale == KPriceScale.indexed
              ? tr(context, 'relativeScaleHint')
              : null,
        ),
    ],
  );
  if (value != null) ref.read(chartPreferencesProvider.notifier).setPriceScale(value);
}

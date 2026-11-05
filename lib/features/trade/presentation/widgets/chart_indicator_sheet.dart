import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/chart_preferences.dart';
import 'chart_parameter_editor.dart';

class ChartIndicatorSheet extends ConsumerWidget {
  const ChartIndicatorSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(chartPreferencesProvider);
    final controller = ref.read(chartPreferencesProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'indicators'),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'indicatorHint'),
          style: const TextStyle(color: AppColors.secondary, fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 20),
        _IndicatorChoices(
          title: tr(context, 'mainIndicators'),
          values: const ['none', 'MA', 'BOLL'],
          selected: preferences.main,
          onSelected: controller.setMain,
        ),
        const SizedBox(height: 20),
        _IndicatorChoices(
          title: tr(context, 'secondaryIndicators'),
          values: const ['none', 'MACD', 'KDJ', 'RSI', 'WR', 'CCI'],
          selected: preferences.secondary,
          onSelected: controller.setSecondary,
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          key: const Key('chart-volume-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'volumeBars'), style: const TextStyle(fontSize: 14)),
          value: preferences.volume,
          onChanged: controller.setVolume,
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          key: const Key('chart-parameters'),
          tilePadding: EdgeInsets.zero,
          title: Text(tr(context, 'indicatorParameters'), style: const TextStyle(fontSize: 14)),
          children: const [ChartParameterEditor()],
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'done'))),
      ],
    );
  }
}

class _IndicatorChoices extends StatelessWidget {
  const _IndicatorChoices({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final String title, selected;
  final List<String> values;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            ChoiceChip(
              key: Key('indicator-$title-$value'),
              label: Text(value == 'none' ? tr(context, value) : value),
              selected: value == selected,
              selectedColor: AppColors.accentSoft,
              checkmarkColor: AppColors.accent,
              backgroundColor: AppColors.raised,
              side: BorderSide(color: value == selected ? AppColors.accent : AppColors.line),
              labelStyle: TextStyle(
                color: value == selected ? AppColors.accent : AppColors.secondary,
                fontSize: 12,
              ),
              onSelected: (_) => onSelected(value),
            ),
        ],
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../portfolio/presentation/mode_settings_sheet.dart';
import '../../../portfolio/presentation/position_order_inputs.dart';
import '../../../settings/presentation/settings_components.dart';
import '../../application/chart_preferences.dart';
import '../trade_theme.dart';
import 'chart_parameter_sheet.dart';
import 'trade_icon.dart';

Future<void> showChartIndicatorSheet(BuildContext context) =>
    showModeSettingsSheet<void>(context, const ChartIndicatorSheet());

/// Indicator selection (Figma 12.05). Choices stay a draft until Confirm.
class ChartIndicatorSheet extends ConsumerStatefulWidget {
  const ChartIndicatorSheet({super.key});
  @override
  ConsumerState<ChartIndicatorSheet> createState() => _ChartIndicatorSheetState();
}

class _ChartIndicatorSheetState extends ConsumerState<ChartIndicatorSheet> {
  late String main, secondary;
  late bool volume;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(chartPreferencesProvider);
    main = preferences.main;
    secondary = preferences.secondary;
    volume = preferences.volume;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ModeSheetBody(
      key: const Key('chart-indicator-sheet'),
      title: tr(context, 'indicators'),
      children: [
        Text(
          tr(context, 'indicatorHint'),
          style: TradeTypography.body.copyWith(
            fontSize: 14,
            height: 17 / 14,
            fontWeight: FontWeight.w400,
            color: TradeColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        _IndicatorChoices(
          title: tr(context, 'mainIndicators'),
          values: const ['none', ...mainIndicatorOptions],
          selected: main,
          onSelected: (value) => setState(() => main = value),
        ),
        const SizedBox(height: 20),
        _IndicatorChoices(
          title: tr(context, 'secondaryIndicators'),
          values: const ['none', ...secondaryIndicatorOptions],
          selected: secondary,
          onSelected: (value) => setState(() => secondary = value),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(child: Text(tr(context, 'volumeBars'), style: TradeTypography.option)),
              SettingsSwitch(
                key: const Key('chart-volume-switch'),
                value: volume,
                label: tr(context, 'volumeBars'),
                onChanged: (value) => setState(() => volume = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          key: const Key('chart-parameters'),
          onTap: () => showChartParameterSheet(context),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'indicatorParameters'),
                    style: TradeTypography.option.copyWith(color: TradeColors.secondary),
                  ),
                ),
                const TradeIcon('chart-chevron', size: 16, color: TradeColors.secondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        PositionActionButton(
          key: const Key('chart-indicator-confirm'),
          label: l.chartSettingsConfirm,
          onPressed: () {
            ref
                .read(chartPreferencesProvider.notifier)
                .setIndicators(main: main, secondary: secondary, volume: volume);
            Navigator.pop(context);
          },
        ),
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
      Text(title, style: TradeTypography.body.copyWith(fontSize: 14, height: 17 / 14)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            _IndicatorChip(
              key: Key('indicator-$title-$value'),
              label: value == 'none' ? tr(context, value) : value,
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
        ],
      ),
    ],
  );
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected ? TradeColors.chipSelectedText : TradeColors.secondary;
    final style = TradeTypography.body.copyWith(fontSize: 14, height: 17 / 14, color: color);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? TradeColors.chipSelected : TradeColors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? TradeColors.chipSelectedText : TradeColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 57),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  ExcludeSemantics(
                    child: Text('✓', style: style.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

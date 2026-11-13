import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../portfolio/presentation/mode_settings_sheet.dart';
import '../../../portfolio/presentation/position_order_inputs.dart';
import '../../application/chart_preferences.dart';
import '../../domain/chart_parameters.dart';
import '../trade_theme.dart';
import 'trade_icon.dart';

Future<void> showChartParameterSheet(BuildContext context) =>
    showModeSettingsSheet<void>(context, const ChartParameterSheet());

/// Indicator parameters (Figma 12.06, dropdown 12.07). Applied on Confirm.
class ChartParameterSheet extends ConsumerStatefulWidget {
  const ChartParameterSheet({super.key});
  @override
  ConsumerState<ChartParameterSheet> createState() => _ChartParameterSheetState();
}

class _ChartParameterSheetState extends ConsumerState<ChartParameterSheet> {
  final _form = GlobalKey<FormState>();
  final _controllers = List.generate(4, (_) => TextEditingController());
  late String _indicator;
  String? _error;

  @override
  void initState() {
    super.initState();
    final main = ref.read(chartPreferencesProvider).main;
    _indicator = indicatorParameterSpecs.containsKey(main) ? main : 'MA';
    _fill();
  }

  void _fill() {
    final values = ref.read(chartPreferencesProvider).parameters[_indicator];
    for (var i = 0; i < values.length; i++) {
      _controllers[i].text = '${values[i]}';
    }
    _error = null;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _confirm() {
    final specs = indicatorParameterSpecs[_indicator]!;
    if (!_form.currentState!.validate()) return;
    final values = List.generate(specs.length, (i) => num.parse(_controllers[i].text.trim()));
    if (_indicator == 'MACD' && values[0] >= values[1]) {
      setState(() => _error = 'invalidMacdPeriods');
      return;
    }
    ref.read(chartPreferencesProvider.notifier).setParameters(_indicator, values);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final specs = indicatorParameterSpecs[_indicator]!;
    return Form(
      key: _form,
      child: ModeSheetBody(
        key: const Key('chart-parameter-sheet'),
        title: tr(context, 'indicatorParameters'),
        children: [
          _FieldLabel(tr(context, 'indicatorParameters')),
          const SizedBox(height: 4),
          _IndicatorSelect(
            selected: _indicator,
            onSelected: (value) => setState(() {
              _indicator = value;
              _fill();
            }),
          ),
          for (var i = 0; i < specs.length; i++) ...[
            const SizedBox(height: 20),
            _FieldLabel(
              tr(context, specs[i].label),
              range: '${specs[i].integer ? 1 : .1}-${specs[i].maximum}',
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: ValueKey('parameter-$_indicator-$i'),
              controller: _controllers[i],
              keyboardType: TextInputType.numberWithOptions(decimal: !specs[i].integer),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(specs[i].integer ? r'\d' : r'[\d.]')),
              ],
              style: TradeTypography.option,
              decoration: _fieldDecoration(),
              onChanged: (_) => _error == null ? null : setState(() => _error = null),
              validator: (text) {
                final value = num.tryParse(text?.trim() ?? '');
                return value != null && specs[i].accepts(value)
                    ? null
                    : tr(context, 'invalidChartParameter');
              },
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, error),
              style: TradeTypography.body.copyWith(color: TradeColors.negative),
            ),
          ],
          const SizedBox(height: 40),
          PositionActionButton(
            key: const Key('apply-chart-parameters'),
            label: AppLocalizations.of(context).chartSettingsConfirm,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration() {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    filled: true,
    fillColor: TradeColors.input,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: border(TradeColors.line),
    enabledBorder: border(TradeColors.line),
    focusedBorder: border(TradeColors.accent),
    errorBorder: border(TradeColors.negative),
    focusedErrorBorder: border(TradeColors.negative),
    errorStyle: TradeTypography.body.copyWith(color: TradeColors.negative),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.range});
  final String label;
  final String? range;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: TradeTypography.body.copyWith(fontSize: 14, height: 20 / 14)),
      ),
      if (range != null)
        Text(range!, style: TradeTypography.body.copyWith(color: TradeColors.muted)),
    ],
  );
}

/// Indicator picker field and its dropdown list (12.07).
class _IndicatorSelect extends StatelessWidget {
  const _IndicatorSelect({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PopupMenuButton<String>(
      key: const Key('parameter-indicator'),
      tooltip: tr(context, 'indicatorParameters'),
      initialValue: selected,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      color: TradeColors.sheet,
      elevation: 0,
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TradeColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      itemBuilder: (context) => [
        for (final name in indicatorParameterSpecs.keys)
          PopupMenuItem(
            key: ValueKey('parameter-indicator-$name'),
            value: name,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TradeTypography.body.copyWith(
                      fontSize: 14,
                      height: 17 / 14,
                      fontWeight: name == selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (name == selected)
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TradeColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TradeIcon('check', size: 12, color: TradeColors.background),
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: TradeColors.card,
          border: Border.all(color: TradeColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(selected, style: TradeTypography.option)),
            const TradeIcon('chart-select-caret', size: 8, color: TradeColors.muted),
          ],
        ),
      ),
    ),
  );
}

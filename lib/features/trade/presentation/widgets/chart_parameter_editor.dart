import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/chart_preferences.dart';
import '../../domain/chart_parameters.dart';

class ChartParameterEditor extends ConsumerStatefulWidget {
  const ChartParameterEditor({super.key});
  @override
  ConsumerState<ChartParameterEditor> createState() => _ChartParameterEditorState();
}

class _ChartParameterEditorState extends ConsumerState<ChartParameterEditor> {
  final _form = GlobalKey<FormState>();
  String _indicator = 'MA';
  final _controllers = List.generate(4, (_) => TextEditingController());
  String? _error;
  @override
  void initState() {
    super.initState();
    _fill(ref.read(chartPreferencesProvider).parameters[_indicator]);
  }

  void _fill(List<num> values) {
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

  @override
  Widget build(BuildContext context) {
    final specs = indicatorParameterSpecs[_indicator]!;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('parameter-indicator'),
            initialValue: _indicator,
            decoration: InputDecoration(labelText: tr(context, 'indicatorParameters')),
            items: [
              for (final name in indicatorParameterSpecs.keys)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _indicator = value;
                _fill(ref.read(chartPreferencesProvider).parameters[value]);
              });
            },
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < specs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey('parameter-$_indicator-$i'),
                controller: _controllers[i],
                keyboardType: TextInputType.numberWithOptions(decimal: !specs[i].integer),
                decoration: InputDecoration(
                  labelText: tr(context, specs[i].label),
                  helperText: '${specs[i].integer ? 1 : .1}–${specs[i].maximum}',
                ),
                validator: (text) {
                  final value = num.tryParse(text ?? '');
                  return value != null && specs[i].accepts(value)
                      ? null
                      : tr(context, 'invalidChartParameter');
                },
              ),
            ),
          if (_error != null)
            Text(tr(context, _error!), style: const TextStyle(color: AppColors.negative)),
          Row(
            children: [
              TextButton(
                key: const Key('reset-chart-parameters'),
                onPressed: () => setState(() => _fill(specs.map((spec) => spec.initial).toList())),
                child: Text(tr(context, 'resetDefaults')),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('apply-chart-parameters'),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  final values = List.generate(
                    specs.length,
                    (i) => num.parse(_controllers[i].text),
                  );
                  if (_indicator == 'MACD' && values[0] >= values[1]) {
                    setState(() => _error = 'invalidMacdPeriods');
                    return;
                  }
                  ref.read(chartPreferencesProvider.notifier).setParameters(_indicator, values);
                  Navigator.pop(context);
                },
                child: Text(tr(context, 'apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

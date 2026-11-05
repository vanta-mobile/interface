class IndicatorParameterSpec {
  const IndicatorParameterSpec(this.label, this.initial, {this.integer = true, this.maximum = 200});
  final String label;
  final num initial;
  final bool integer;
  final num maximum;
  bool accepts(num value) =>
      value.isFinite &&
      value >= (integer ? 1 : .1) &&
      value <= maximum &&
      (!integer || value == value.round());
}

const indicatorParameterSpecs = <String, List<IndicatorParameterSpec>>{
  'MA': [
    IndicatorParameterSpec('period1', 5),
    IndicatorParameterSpec('period2', 10),
    IndicatorParameterSpec('period3', 30),
    IndicatorParameterSpec('period4', 60),
  ],
  'BOLL': [
    IndicatorParameterSpec('period', 20),
    IndicatorParameterSpec('deviations', 2, integer: false, maximum: 10),
  ],
  'MACD': [
    IndicatorParameterSpec('fastPeriod', 12),
    IndicatorParameterSpec('slowPeriod', 26),
    IndicatorParameterSpec('signalPeriod', 9),
  ],
  'KDJ': [
    IndicatorParameterSpec('period', 9),
    IndicatorParameterSpec('smoothK', 3),
    IndicatorParameterSpec('smoothD', 3),
  ],
  'RSI': [IndicatorParameterSpec('period', 14)],
  'WR': [IndicatorParameterSpec('period', 14)],
  'CCI': [IndicatorParameterSpec('period', 20)],
};

class ChartParameters {
  const ChartParameters._(this._values);
  const ChartParameters() : _values = const {};
  final Map<String, List<num>> _values;
  List<num> operator [](String indicator) =>
      _values[indicator] ??
      List.unmodifiable(indicatorParameterSpecs[indicator]!.map((p) => p.initial));
  ChartParameters withValues(String indicator, List<num> values) {
    final specs = indicatorParameterSpecs[indicator];
    if (specs == null ||
        values.length != specs.length ||
        !List.generate(values.length, (i) => specs[i].accepts(values[i])).every((v) => v) ||
        (indicator == 'MACD' && values[0] >= values[1])) {
      throw ArgumentError.value(values, indicator, 'Invalid indicator parameters');
    }
    return ChartParameters._(
      Map.unmodifiable({..._values, indicator: List<num>.unmodifiable(values)}),
    );
  }
}

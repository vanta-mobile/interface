import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../domain/chart_parameters.dart';

class ChartPreferences {
  const ChartPreferences({
    this.main = 'none',
    this.secondary = 'none',
    this.line = false,
    this.chartType = KChartType.candles,
    this.priceScale = KPriceScale.regular,
    this.parameters = const ChartParameters(),
    this.volume = true,
    this.depth = false,
  });
  final String main, secondary;
  final bool line, volume, depth;
  final KChartType chartType;
  final KPriceScale priceScale;
  final ChartParameters parameters;

  ChartPreferences copyWith({
    String? main,
    String? secondary,
    bool? line,
    bool? volume,
    bool? depth,
    KChartType? chartType,
    KPriceScale? priceScale,
    ChartParameters? parameters,
  }) => ChartPreferences(
    main: main ?? this.main,
    secondary: secondary ?? this.secondary,
    line: line ?? this.line,
    volume: volume ?? this.volume,
    depth: depth ?? this.depth,
    chartType: chartType ?? this.chartType,
    priceScale: priceScale ?? this.priceScale,
    parameters: parameters ?? this.parameters,
  );
}

// Both embedded and fullscreen workspaces share the same display preferences.
final chartPreferencesProvider = NotifierProvider<ChartPreferencesController, ChartPreferences>(
  ChartPreferencesController.new,
);

class ChartPreferencesController extends Notifier<ChartPreferences> {
  @override
  ChartPreferences build() => const ChartPreferences();
  void setDepth(bool value) => state = state.copyWith(depth: value);
  void setMain(String value) => state = state.copyWith(main: value);
  void setSecondary(String value) => state = state.copyWith(secondary: value);
  void setLine(bool value) => setChartType(value ? KChartType.line : KChartType.candles);
  void setChartType(KChartType value) => state = state.copyWith(
    chartType: value,
    line: [
      KChartType.line,
      KChartType.lineWithMarkers,
      KChartType.stepLine,
      KChartType.area,
      KChartType.baseline,
    ].contains(value),
  );
  void setPriceScale(KPriceScale value) => state = state.copyWith(priceScale: value);
  void setParameters(String indicator, List<num> values) =>
      state = state.copyWith(parameters: state.parameters.withValues(indicator, values));
  void resetParameters() => state = state.copyWith(parameters: const ChartParameters());
  void setVolume(bool value) => state = state.copyWith(volume: value);
}

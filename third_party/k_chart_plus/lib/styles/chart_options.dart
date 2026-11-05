import 'dart:math' as math;

enum KChartType {
  candles,
  hollowCandles,
  bars,
  line,
  lineWithMarkers,
  stepLine,
  area,
  baseline,
  columns,
  highLow,
  heikinAshi
}

enum KPriceScale { regular, logarithmic, percentage, indexed }

/// Only drawing coordinates/labels change. Source prices stay in quote units.
class KPriceAxis {
  const KPriceAxis(this.mode, this.reference);
  final KPriceScale mode;
  final double reference;
  double coordinate(double price) => mode == KPriceScale.logarithmic ? math.log(price) : price;
  double price(double coordinate) =>
      mode == KPriceScale.logarithmic ? math.exp(coordinate) : coordinate;
  String format(double price, int precision) => switch (mode) {
        KPriceScale.percentage => '${((price / reference - 1) * 100).toStringAsFixed(2)}%',
        KPriceScale.indexed => (price / reference * 100).toStringAsFixed(2),
        _ => price.toStringAsFixed(precision),
      };
}

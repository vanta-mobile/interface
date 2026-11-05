import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/market/domain/market.dart';
import 'package:vanta/features/trade/domain/chart_parameters.dart';
import 'package:vanta/features/trade/presentation/widgets/chart_entities.dart';

void main() {
  test('logarithmic spacing and relative labels preserve quote prices', () {
    const axis = KPriceAxis(KPriceScale.logarithmic, 10);
    expect(axis.price(axis.coordinate(123.45)), closeTo(123.45, 1e-9));
    final renderer = MainRenderer(
      const Rect.fromLTWH(0, 0, 400, 300),
      1000,
      10,
      0,
      [],
      false,
      2,
      const KChartStyle(),
      const KChartColors(),
      1,
      VerticalTextAlignment.right,
      16,
      priceAxis: axis,
    );
    expect(
      renderer.getY(10) - renderer.getY(100),
      closeTo(renderer.getY(100) - renderer.getY(1000), 1e-9),
    );
    expect(renderer.getY(-1).isFinite, true);
    expect(const KPriceAxis(KPriceScale.percentage, 100).format(125, 2), '25.00%');
    expect(const KPriceAxis(KPriceScale.indexed, 100).format(125, 2), '125.00');
    expect(const KPriceAxis(KPriceScale.regular, 100).format(125, 2), '125.00');
  });
  test('Heikin Ashi is a separate display series and leaves original OHLC intact', () {
    const candles = [
      Candle(time: 1, open: 10, high: 16, low: 8, close: 14, volume: 7),
      Candle(time: 2, open: 14, high: 20, low: 13, close: 19, volume: 8),
    ];
    final display = chartEntities(candles, heikinAshi: true);
    expect(display.first.open, 12);
    expect(display.first.close, 12);
    expect(display.last.open, 12);
    expect(display.last.close, 16.5);
    expect(display.last.low, 12);
    expect(candles.last.close, 19);
    expect(display.last.vol, candles.last.volume);
  });
  test('parameter boundaries reject invalid values and retain immutable previous settings', () {
    const initial = ChartParameters();
    final values = <num>[10, 2.5];
    final next = initial.withValues('BOLL', values);
    values[0] = 99;
    expect(initial['BOLL'], [20, 2]);
    expect(next['BOLL'], [10, 2.5]);
    expect(() => next['BOLL'][0] = 5, throwsUnsupportedError);
    for (final values in [
      [0, 26, 9],
      [12.5, 26, 9],
      [30, 26, 9],
      [12, 26, double.nan],
    ]) {
      expect(() => initial.withValues('MACD', values), throwsArgumentError);
    }
    expect(() => initial.withValues('RSI', [201]), throwsArgumentError);
  });
  test('BOLL uses configured period and decimal deviations on original close values', () {
    final data = List.generate(
      4,
      (i) =>
          KLineEntity.fromCustom(time: i, open: i + 1, high: i + 2, low: .5, close: i + 1, vol: 1),
    );
    BOLLIndicator(period: 3, multiplier: 2.5).calc(data);
    expect(data[1].boll?.mid, null);
    expect(data[2].boll?.mid, 2);
    expect(data[2].boll?.up, closeTo(2 + 2.5 * math.sqrt(2 / 3), 1e-9));
    expect(data[3].boll?.mid, 3);
  });
  test('RSI and WR configured lookbacks use the requested number of candles', () {
    final data = List.generate(
      8,
      (i) => KLineEntity.fromCustom(
        time: i,
        open: i + 1,
        high: i + 2,
        low: i + .5,
        close: i + 1,
        vol: 1,
      ),
    );
    RSIIndicator(calcParams: [3]).calc(data);
    expect(data[1].rsi, null);
    expect(data[2].rsi, 100);
    WRIndicator(calcParams: [3]).calc(data);
    expect(data[1].r, null);
    expect(data[2].r, closeTo(-100 / 3.5, 1e-9));
  });
}

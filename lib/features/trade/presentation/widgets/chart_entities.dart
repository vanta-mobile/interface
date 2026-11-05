import 'dart:math' as math;

import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../market/domain/market.dart';

/// Derived display candles never replace transport/domain prices.
List<KLineEntity> chartEntities(List<Candle> candles, {bool heikinAshi = false}) {
  double? previousOpen, previousClose;
  return candles.map((c) {
    var open = c.open, close = c.close, high = c.high, low = c.low;
    if (heikinAshi) {
      close = (c.open + c.high + c.low + c.close) / 4;
      open = previousOpen == null ? (c.open + c.close) / 2 : (previousOpen! + previousClose!) / 2;
      high = math.max(c.high, math.max(open, close));
      low = math.min(c.low, math.min(open, close));
      previousOpen = open;
      previousClose = close;
    }
    return KLineEntity.fromCustom(
      open: open,
      close: close,
      high: high,
      low: low,
      time: c.time,
      vol: c.volume,
    );
  }).toList();
}

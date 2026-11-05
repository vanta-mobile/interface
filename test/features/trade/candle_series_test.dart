import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/candle_series.dart';
import 'package:vanta/features/market/domain/market.dart';

Candle bar(int minute, {int event = 0, bool closed = false, double price = 100}) => Candle(
  time: minute * 60000,
  open: 100,
  high: 200,
  low: 50,
  close: price,
  volume: 10,
  eventTime: event,
  closed: closed,
);
void main() {
  const key = SeriesKey('BTCUSDT', '1m');
  test('REST merges with buffered WS; current live bar wins', () {
    final series = CandleSeries(key);
    final revision = series.revision;
    series.mergeLive(key, bar(35, event: 35001, price: 125));
    series.mergeHistory(key, [
      bar(33, closed: true),
      bar(34, closed: true),
      bar(35, price: 110),
    ], requestRevision: revision);
    expect(series.candles.map((e) => e.time), [1980000, 2040000, 2100000]);
    expect(series.candles.last.close, 125);
  });
  test('same open time is replaced; stale and unclosed updates cannot undo close', () {
    final series = CandleSeries(key);
    series.mergeLive(key, bar(35, event: 100, price: 110));
    series.mergeLive(key, bar(35, event: 200, price: 120));
    expect(series.candles, hasLength(1));
    expect(series.mergeLive(key, bar(35, event: 150, price: 115)), false);
    series.mergeLive(key, bar(35, event: 200, closed: true, price: 121));
    expect(series.mergeLive(key, bar(35, event: 300, price: 130)), false);
    expect(series.candles.single.close, 121);
    expect(series.candles.single.closed, true);
  });
  test('gap includes previous bar; inclusive history corrects and deduplicates', () {
    final series = CandleSeries(key);
    series.mergeHistory(key, [bar(30)], requestRevision: 0);
    series.mergeLive(key, bar(34, event: 200));
    expect(series.missingRange, (1800000, 2099999));
    series.mergeHistory(key, [
      for (var i = 30; i <= 34; i++) bar(i, closed: i < 34, price: 112),
    ], requestRevision: series.revision);
    expect(series.missingRange, null);
    expect(series.candles, hasLength(5));
    expect(series.candles.first.close, 112);
  });
  test('REST cannot erase closed status or WS event watermark', () {
    final series = CandleSeries(key);
    series.mergeLive(key, bar(30, event: 300, closed: true));
    series.mergeHistory(key, [bar(30, closed: true, price: 150)], requestRevision: series.revision);
    expect(series.candles.single.close, 150);
    expect(series.mergeLive(key, bar(30, event: 200, closed: true, price: 120)), false);
    series.mergeHistory(key, [bar(30, price: 120)], requestRevision: series.revision);
    expect(series.candles.single.closed, true);
  });
  test('market, symbol and interval are isolated; cache retention is bounded', () {
    final series = CandleSeries(key, capacity: 3);
    for (final wrong in [
      const SeriesKey('ETHUSDT', '1m'),
      const SeriesKey('BTCUSDT', '5m'),
      const SeriesKey('BTCUSDT', '1m', market: 'spot'),
      const SeriesKey('BTCUSDT', '1m', market: 'binance-usdm'),
    ]) {
      expect(series.mergeLive(wrong, bar(1, event: 1)), false);
      series.mergeHistory(wrong, [bar(0)], requestRevision: 0);
    }
    for (var i = 0; i < 10; i++) {
      series.mergeLive(key, bar(i, event: i + 1));
    }
    expect(series.candles.map((e) => e.time), [420000, 480000, 540000]);
    expect(series.missingRange, null);
  });
}

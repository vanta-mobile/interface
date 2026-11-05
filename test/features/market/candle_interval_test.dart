import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/candle_series.dart';
import 'package:vanta/features/market/domain/market.dart';

int utc(int year, int month, [int day = 1]) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch;

void main() {
  test('all 15 Aster intervals have correctly bounded UTC open times', () {
    expect(candleIntervals, hasLength(15));
    final time = utc(2024, 3, 13) + 12345;
    for (final interval in candleIntervals) {
      final open = candleOpenAt(interval, time);
      expect(open, lessThanOrEqualTo(time));
      expect(shiftCandleOpen(interval, open), greaterThan(time));
      expect(shiftCandleOpen(interval, shiftCandleOpen(interval, open), -1), open);
    }
    expect(candleOpenAt('1w', utc(2024, 3, 13)), utc(2024, 3, 11));
  });
  test('monthly pagination and gap detection respect leap years and month lengths', () {
    expect(shiftCandleOpen('1M', utc(2024, 1)), utc(2024, 2));
    expect(shiftCandleOpen('1M', utc(2024, 2)), utc(2024, 3));
    expect(shiftCandleOpen('1M', utc(2024, 1), -1), utc(2023, 12));
    expect(candleCount('1M', utc(2024, 1), utc(2024, 4) - 1), 3);
    const key = SeriesKey('BTCUSDT', '1M');
    final series = CandleSeries(key);
    Candle bar(int month) => Candle(
      time: utc(2024, month),
      open: 10,
      high: 12,
      low: 9,
      close: 11,
      volume: 1,
      closed: true,
    );
    series.mergeHistory(key, [bar(1), bar(2), bar(3)], requestRevision: 0);
    expect(series.missingRange, null);
    series.mergeHistory(key, [bar(5)], requestRevision: 0);
    expect(series.missingRange, (utc(2024, 3), utc(2024, 6) - 1));
    expect(() => intervalMilliseconds('1M'), throwsArgumentError);
  });
}

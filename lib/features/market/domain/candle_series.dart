import 'market.dart';
import 'candle_interval.dart';
export 'candle_interval.dart';

/// Identifies the market, instrument and interval independently of UI selection.
class SeriesKey {
  const SeriesKey(this.symbol, this.interval, {this.market = 'aster-usdt'});
  final String market, symbol, interval;
  int get step => intervalMilliseconds(interval);
  int shift(int time, [int count = 1]) => shiftCandleOpen(interval, time, count);
  @override
  bool operator ==(Object other) =>
      other is SeriesKey &&
      other.market == market &&
      other.symbol == symbol &&
      other.interval == interval;
  @override
  int get hashCode => Object.hash(market, symbol, interval);
}

class CandleSeries {
  CandleSeries(this.key, {this.capacity = 600});
  final SeriesKey key;
  final int capacity;
  final _entries = <int, _Entry>{};
  int revision = 0;
  int? get lastTime => _entries.isEmpty ? null : _entries.keys.reduce((a, b) => a > b ? a : b);
  List<Candle> get candles =>
      (_entries.values.map((e) => e.candle).toList()..sort((a, b) => a.time.compareTo(b.time)));

  bool mergeLive(SeriesKey identity, Candle candle) {
    if (identity != key) return false;
    final previous = _entries[candle.time];
    final old = previous?.candle;
    if (old != null) {
      if (old.closed && !candle.closed) return false;
      if (candle.eventTime < previous!.eventWatermark) return false;
      if (candle.eventTime == previous.eventWatermark && (!candle.closed || old.closed)) {
        return false;
      }
    }
    _entries[candle.time] = _Entry(candle, ++revision, candle.eventTime);
    _trim();
    return true;
  }

  /// REST has no WS event version. Protect messages received during this request;
  /// never replace a live in-progress candle with a REST in-progress snapshot.
  void mergeHistory(SeriesKey identity, List<Candle> history, {required int requestRevision}) {
    if (identity != key) return;
    for (final candle in history) {
      final old = _entries[candle.time];
      if (old != null) {
        if (old.revision > requestRevision) continue;
        if (old.candle.closed && !candle.closed) continue;
        if (!candle.closed && old.candle.eventTime > 0) continue;
      }
      _entries[candle.time] = _Entry(candle, old?.revision ?? 0, old?.eventWatermark ?? 0);
    }
    _trim();
  }

  /// Inclusive range starts at the preceding candle to also correct its old state.
  (int, int)? get missingRange {
    final times = _entries.keys.toList()..sort();
    for (var i = 1; i < times.length; i++) {
      if (times[i] > key.shift(times[i - 1])) return (times[i - 1], key.shift(times[i]) - 1);
    }
    return null;
  }

  void _trim() {
    if (_entries.length <= capacity) return;
    final times = _entries.keys.toList()..sort();
    for (final time in times.take(_entries.length - capacity)) {
      _entries.remove(time);
    }
  }
}

class _Entry {
  const _Entry(this.candle, this.revision, this.eventWatermark);
  final Candle candle;
  final int revision, eventWatermark;
}

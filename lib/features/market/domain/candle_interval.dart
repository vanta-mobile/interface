const candleIntervals = [
  '1m',
  '3m',
  '5m',
  '15m',
  '30m',
  '1h',
  '2h',
  '4h',
  '6h',
  '8h',
  '12h',
  '1d',
  '3d',
  '1w',
  '1M',
];
const quickCandleIntervals = ['1m', '5m', '15m', '1h', '4h', '1d'];

int intervalMilliseconds(String interval) {
  if (!candleIntervals.contains(interval) || interval == '1M') {
    throw ArgumentError.value(interval, 'interval', 'Not a fixed duration');
  }
  final count = int.parse(interval.substring(0, interval.length - 1));
  return count *
      switch (interval[interval.length - 1]) {
        'm' => 60000,
        'h' => 3600000,
        'd' => 86400000,
        'w' => 604800000,
        _ => throw ArgumentError.value(interval),
      };
}

/// Move between exchange UTC open times; a month is never a fixed 30 days.
int shiftCandleOpen(String interval, int time, [int count = 1]) {
  if (interval == '1M') {
    final date = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);
    return DateTime.utc(date.year, date.month + count).millisecondsSinceEpoch;
  }
  return time + intervalMilliseconds(interval) * count;
}

int candleOpenAt(String interval, int time) {
  if (interval == '1M') {
    final date = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);
    return DateTime.utc(date.year, date.month).millisecondsSinceEpoch;
  }
  final step = intervalMilliseconds(interval);
  // Aster weeks begin on Monday, unlike the Unix epoch's Thursday.
  const monday = 4 * 86400000;
  final origin = interval == '1w' ? monday : 0;
  return ((time - origin) / step).floor() * step + origin;
}

int candleCount(String interval, int start, int end) {
  if (interval == '1M') {
    final first = DateTime.fromMillisecondsSinceEpoch(start, isUtc: true);
    final last = DateTime.fromMillisecondsSinceEpoch(end, isUtc: true);
    return (last.year - first.year) * 12 + last.month - first.month + 1;
  }
  return (end - start) ~/ intervalMilliseconds(interval) + 1;
}

/// Public market limits, never the current wallet's leverage or capacity.
class PublicLeverage {
  PublicLeverage(Iterable<(int, int)> ranges) : ranges = List.unmodifiable(ranges);
  final List<(int, int)> ranges;

  int defaultLeverage({int preferred = 20}) {
    final supported = <int>{
      for (final range in ranges)
        for (var value = range.$1; value <= range.$2; value++) value,
    }.toList()..sort();
    if (supported.isEmpty) throw StateError('No supported leverage');
    return supported.where((value) => value <= preferred).lastOrNull ?? supported.first;
  }
}

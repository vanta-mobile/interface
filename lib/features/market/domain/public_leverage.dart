/// Public market limits, never the current wallet's leverage or capacity.
class PublicLeverage {
  PublicLeverage(Iterable<(int, int)> ranges) : ranges = List.unmodifiable(ranges);
  final List<(int, int)> ranges;

  /// Highest leverage any bracket opens, as advertised for the market.
  int get maximumLeverage => ranges.map((range) => range.$2).reduce((a, b) => a > b ? a : b);

  /// PRD first visit presets 10×; markets that cannot open 10× use the
  /// nearest supported value below it, or their lowest one.
  int defaultLeverage({int preferred = 10}) {
    final supported = <int>{
      for (final range in ranges)
        for (var value = range.$1; value <= range.$2; value++) value,
    }.toList()..sort();
    if (supported.isEmpty) throw StateError('No supported leverage');
    return supported.where((value) => value <= preferred).lastOrNull ?? supported.first;
  }
}

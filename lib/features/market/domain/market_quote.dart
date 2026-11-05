import 'package:decimal/decimal.dart';

import 'market_precision.dart';
import 'market_descriptor.dart';

/// Public market values. Null denotes unavailable data, never a zero balance.
class MarketQuote {
  const MarketQuote({
    required this.symbol,
    required this.base,
    required this.precision,
    this.price,
    this.change,
    this.quoteVolume,
    this.funding,
    this.descriptor = const MarketDescriptor.empty(),
  });

  final String symbol, base;
  final MarketPrecision precision;
  final Decimal? price, change, quoteVolume, funding;
  final MarketDescriptor descriptor;
}

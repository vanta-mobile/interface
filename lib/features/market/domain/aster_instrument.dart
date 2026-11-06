import 'market_precision.dart';
import 'market_descriptor.dart';

class AsterInstrument {
  AsterInstrument({
    required this.symbol,
    required this.base,
    required Map<String, Object?> ticker,
    this.precision = const MarketPrecision(),
    this.descriptor = const MarketDescriptor.empty(),
  }) : ticker = Map.unmodifiable(ticker);
  final String symbol, base;
  final Map<String, Object?> ticker;
  final MarketPrecision precision;
  final MarketDescriptor descriptor;
}

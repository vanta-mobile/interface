import 'market_precision.dart';
import 'market_descriptor.dart';

class AsterInstrument {
  AsterInstrument({
    required this.symbol,
    required this.base,
    this.quote = 'USDT',
    required Map<String, Object?> ticker,
    this.precision = const MarketPrecision(),
    this.descriptor = const MarketDescriptor.empty(),
  }) : ticker = Map.unmodifiable(ticker);
  final String symbol, base;

  /// Exchange quote asset. The public catalog only admits USDT-quoted
  /// perpetuals, so this is the default for hand-built instruments.
  final String quote;
  final Map<String, Object?> ticker;
  final MarketPrecision precision;
  final MarketDescriptor descriptor;
}

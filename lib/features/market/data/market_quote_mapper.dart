import 'package:decimal/decimal.dart';

import '../domain/market_quote.dart';
import 'aster_service.dart';

MarketQuote mapMarketQuote(AsterInstrument instrument) {
  Decimal? number(String key, {bool nonnegative = false}) {
    final value = Decimal.tryParse('${instrument.ticker[key]}');
    return value == null || (nonnegative && value < Decimal.zero) ? null : value;
  }

  return MarketQuote(
    symbol: instrument.symbol,
    base: instrument.base,
    precision: instrument.precision,
    price: number('lastPrice', nonnegative: true),
    change: number('priceChangePercent'),
    quoteVolume: number('quoteVolume', nonnegative: true),
    funding: number('lastFundingRate'),
    descriptor: instrument.descriptor,
  );
}

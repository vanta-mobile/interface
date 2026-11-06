import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_quote_mapper.dart';

void main() {
  test('market summaries preserve raw decimal funding and quote volume', () {
    final quote = mapMarketQuote(
      AsterInstrument(
        symbol: 'BTCUSDT',
        base: 'BTC',
        ticker: {
          'lastPrice': '0.0000010203',
          'priceChangePercent': '-1.76',
          'quoteVolume': '1234567890.0123456789',
          'lastFundingRate': '0.000345',
          'volume': '999',
        },
      ),
    );
    expect(quote.price, Decimal.parse('0.0000010203'));
    expect(quote.change, Decimal.parse('-1.76'));
    expect(quote.quoteVolume, Decimal.parse('1234567890.0123456789'));
    expect(quote.funding, Decimal.parse('0.000345'));
  });
  test('missing, invalid and negative unsigned values differ from a real zero', () {
    final quote = mapMarketQuote(
      AsterInstrument(
        symbol: 'BTCUSDT',
        base: 'BTC',
        ticker: {
          'lastPrice': 'NaN',
          'priceChangePercent': 'Infinity',
          'quoteVolume': '-1',
          'lastFundingRate': '0',
        },
      ),
    );
    expect(quote.price, null);
    expect(quote.change, null);
    expect(quote.quoteVolume, null);
    expect(quote.funding, Decimal.zero);
  });
}

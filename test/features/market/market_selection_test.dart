import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/market_descriptor_mapper.dart';
import 'package:vanta/features/market/domain/market_descriptor.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/market/domain/market_quote.dart';
import 'package:vanta/features/market/domain/market_selection.dart';

MarketQuote quote(String symbol, {String name = '', List<String> aliases = const []}) =>
    MarketQuote(
      symbol: symbol,
      base: symbol.replaceFirst(RegExp(r'USDT$'), ''),
      precision: const MarketPrecision(),
      descriptor: MarketDescriptor(name: name, aliases: aliases),
    );

void main() {
  final quotes = [
    quote('AITOKENUSDT', name: 'Bitcoin derivative'),
    quote('BTCUSDT', aliases: ['Bitcoin', '比特币']),
    quote('ETHUSDT', name: 'Ethereum', aliases: ['以太坊']),
    quote('XAUUSDT', name: 'Gold', aliases: ['黄金']),
    quote('USD1TESTUSDT', name: 'New AI', aliases: ['Top']),
    quote('FUTUREUSDT'),
    quote('RWAUSDT'),
  ];
  List<String> select(MarketSelection selection, [Set<String> favorites = const {}]) =>
      selectMarkets(quotes, selection, favorites).map((q) => q.symbol).toList();

  test('matches exchange names and aliases, trims whitespace and ranks exact identities first', () {
    expect(select(const MarketSelection(query: ' BiTcOiN ')), ['AITOKENUSDT', 'BTCUSDT']);
    expect(select(const MarketSelection(query: '比特币')), ['BTCUSDT']);
    expect(select(const MarketSelection(query: '黄金')), ['XAUUSDT']);
    expect(select(const MarketSelection(query: 'eth')), ['ETHUSDT']);
    final overlap = [quote('BTCXUSDT'), quote('BTCUSDT'), quote('ALTUSDT', name: 'BTC')];
    expect(selectMarkets(overlap, const MarketSelection(query: 'btc'), {}).map((q) => q.symbol), [
      'BTCUSDT',
      'BTCXUSDT',
      'ALTUSDT',
    ]);
  });

  test('favorites intersect search', () {
    expect(select(const MarketSelection(onlyFavorites: true), {'ETHUSDT', 'XAUUSDT'}), [
      'ETHUSDT',
      'XAUUSDT',
    ]);
    expect(
      select(const MarketSelection(onlyFavorites: true, query: '黄金'), {'ETHUSDT', 'XAUUSDT'}),
      ['XAUUSDT'],
    );
    expect(select(const MarketSelection(onlyFavorites: true, query: '比特币'), {'ETHUSDT'}), isEmpty);
    expect(select(const MarketSelection(onlyFavorites: true)), isEmpty);
  });

  test('default order remains stable with no search and output cannot be mutated', () {
    expect(select(const MarketSelection()), quotes.map((q) => q.symbol));
    expect(
      () => selectMarkets(quotes, const MarketSelection(), {}).clear(),
      throwsUnsupportedError,
    );
  });

  test('optional labels are validated, deduplicated and immutable', () {
    final descriptor = mapMarketDescriptor({
      'name': ' Gold ',
      'tags': ['黄金', 'gold', '黄金', '', 17, '\u0000payload'],
      'underlyingSubType': ['Commodities', 'ETF', 'ETF'],
      'onboardDate': 9999999999999,
    });
    expect(descriptor.name, 'Gold');
    expect(descriptor.aliases, ['黄金', 'gold']);
    expect(() => descriptor.aliases.clear(), throwsUnsupportedError);
    final unknown = mapMarketDescriptor({
      'name': {'raw': 'invalid'},
      'tags': 'AI',
      'underlyingSubType': ['top'],
      'onboardDate': 9999999999999,
    });
    expect(unknown.name, '');
    expect(unknown.aliases, isEmpty);
  });
}

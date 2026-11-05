import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/market_descriptor_mapper.dart';
import 'package:vanta/features/market/domain/market_descriptor.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/market/domain/market_quote.dart';
import 'package:vanta/features/market/domain/market_selection.dart';

MarketQuote quote(
  String symbol, {
  String name = '',
  List<String> aliases = const [],
  List<String> categories = const [],
}) => MarketQuote(
  symbol: symbol,
  base: symbol.replaceFirst(RegExp(r'USDT$'), ''),
  precision: const MarketPrecision(),
  descriptor: MarketDescriptor(name: name, aliases: aliases, categories: categories),
);

void main() {
  final quotes = [
    quote('AITOKENUSDT', name: 'Bitcoin derivative', categories: ['Meme']),
    quote('BTCUSDT', aliases: ['Bitcoin', '比特币'], categories: ['Top', 'AI']),
    quote('ETHUSDT', name: 'Ethereum', aliases: ['以太坊'], categories: ['Top']),
    quote('XAUUSDT', name: 'Gold', aliases: ['黄金'], categories: ['Commodities']),
    quote('USD1TESTUSDT', name: 'New AI', aliases: ['Top']),
    quote('FUTUREUSDT', categories: ['pre-launch']),
    quote('RWAUSDT', categories: ['USD1-RWA']),
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

  test(
    'categories intersect favorites and search; names and quote suffixes cannot invent membership',
    () {
      expect(select(const MarketSelection(category: MarketCategory.top)), ['BTCUSDT', 'ETHUSDT']);
      expect(select(const MarketSelection(category: MarketCategory.ai)), ['BTCUSDT']);
      expect(
        select(const MarketSelection(category: MarketCategory.top, onlyFavorites: true), {
          'ETHUSDT',
          'XAUUSDT',
        }),
        ['ETHUSDT'],
      );
      expect(select(const MarketSelection(category: MarketCategory.top, query: '比特币')), [
        'BTCUSDT',
      ]);
      expect(select(const MarketSelection(category: MarketCategory.rwa)), ['RWAUSDT']);
      expect(select(const MarketSelection(category: MarketCategory.preLaunch)), ['FUTUREUSDT']);
      expect(select(const MarketSelection(category: MarketCategory.meme, query: '黄金')), isEmpty);
      expect(select(const MarketSelection(onlyFavorites: true)), isEmpty);
    },
  );

  test('default order remains stable with no search and output cannot be mutated', () {
    expect(select(const MarketSelection()), quotes.map((q) => q.symbol));
    expect(
      () => selectMarkets(quotes, const MarketSelection(), {}).clear(),
      throwsUnsupportedError,
    );
  });

  test('optional labels are validated, deduplicated and immutable without guessing categories', () {
    final descriptor = mapMarketDescriptor({
      'name': ' Gold ',
      'tags': ['黄金', 'gold', '黄金', '', 17, '\u0000payload'],
      'underlyingSubType': ['Commodities', 'ETF', 'ETF'],
      'onboardDate': 9999999999999,
    });
    expect(descriptor.name, 'Gold');
    expect(descriptor.aliases, ['黄金', 'gold']);
    expect(descriptor.categories, {'Commodities', 'ETF'});
    expect(() => descriptor.aliases.clear(), throwsUnsupportedError);
    expect(() => descriptor.categories.clear(), throwsUnsupportedError);
    final unknown = mapMarketDescriptor({
      'name': {'raw': 'invalid'},
      'tags': 'AI',
      'underlyingSubType': ['top'],
      'onboardDate': 9999999999999,
    });
    expect(unknown.name, '');
    expect(unknown.aliases, isEmpty);
    expect(unknown.categories, {'top'}); // no invented Top/New labels
  });
}

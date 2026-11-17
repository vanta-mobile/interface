import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/market_selection_provider.dart';
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

  test('columns sort both ways with unknown values last and catalog order for ties', () {
    MarketQuote priced(String symbol, String? volume, {String? mark}) => MarketQuote(
      symbol: symbol,
      base: symbol,
      precision: const MarketPrecision(),
      quoteVolume: volume == null ? null : Decimal.parse(volume),
      markPrice: mark == null ? null : Decimal.parse(mark),
    );
    final rows = [
      priced('AUSDT', '5', mark: '2'),
      priced('BUSDT', null, mark: '1'),
      priced('CUSDT', '9', mark: '10'),
      priced('DUSDT', '5'),
    ];
    List<String> sorted(MarketSort sort, bool descending, [Map<String, Decimal> oi = const {}]) =>
        selectMarkets(
          rows,
          MarketSelection(sort: sort, descending: descending),
          {},
          openInterest: oi,
        ).map((q) => q.symbol).toList();
    expect(sorted(MarketSort.volume, true), ['CUSDT', 'AUSDT', 'DUSDT', 'BUSDT']);
    expect(sorted(MarketSort.volume, false), ['AUSDT', 'DUSDT', 'CUSDT', 'BUSDT']);
    expect(sorted(MarketSort.symbol, false), ['AUSDT', 'BUSDT', 'CUSDT', 'DUSDT']);
    // Open interest is compared in quote value: base amount × mark price.
    final oi = {'AUSDT': Decimal.fromInt(10), 'BUSDT': Decimal.fromInt(30), 'CUSDT': Decimal.one};
    expect(sorted(MarketSort.openInterest, true, oi), ['BUSDT', 'AUSDT', 'CUSDT', 'DUSDT']);
    expect(openInterestValue(rows[0], Decimal.fromInt(10)), Decimal.fromInt(20));
    expect(openInterestValue(rows[3], Decimal.fromInt(10)), isNull);
  });

  test('a column cycles descending, ascending, then back to catalog order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(marketSelectionProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(marketSelectionProvider.notifier);
    MarketSelection read() => container.read(marketSelectionProvider);
    controller.search('btc');
    controller.sortBy(MarketSort.volume);
    expect((read().sort, read().descending), (MarketSort.volume, true));
    controller.sortBy(MarketSort.volume);
    expect((read().sort, read().descending), (MarketSort.volume, false));
    controller.sortBy(MarketSort.volume);
    expect(read().sort, isNull);
    controller.sortBy(MarketSort.symbol);
    expect((read().sort, read().descending), (MarketSort.symbol, false));
    controller.favorites(true);
    expect((read().sort, read().query, read().onlyFavorites), (MarketSort.symbol, 'btc', true));
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

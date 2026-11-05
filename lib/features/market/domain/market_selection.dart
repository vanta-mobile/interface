import 'market_descriptor.dart';
import 'market_quote.dart';

class MarketSelection {
  const MarketSelection({
    this.query = '',
    this.category = MarketCategory.all,
    this.onlyFavorites = false,
  });
  final String query;
  final MarketCategory category;
  final bool onlyFavorites;
}

List<MarketQuote> selectMarkets(
  Iterable<MarketQuote> quotes,
  MarketSelection selection,
  Set<String> favorites,
) {
  final query = selection.query.trim().toUpperCase();
  bool exact(MarketQuote quote) =>
      quote.symbol.toUpperCase() == query || quote.base.toUpperCase() == query;
  bool matches(MarketQuote quote) =>
      query.isEmpty ||
      [
        quote.symbol,
        quote.base,
        quote.descriptor.name,
        ...quote.descriptor.aliases,
      ].any((value) => value.toUpperCase().contains(query));
  final filtered = quotes
      .where(
        (quote) =>
            (selection.category.tag == null ||
                quote.descriptor.categories.contains(selection.category.tag)) &&
            (!selection.onlyFavorites || favorites.contains(quote.symbol)) &&
            matches(quote),
      )
      .toList();
  // Exact identities precede partial labels, retaining the stable metadata
  // order within each group. Price updates never cause default row jumps.
  return List.unmodifiable([...filtered.where(exact), ...filtered.where((quote) => !exact(quote))]);
}

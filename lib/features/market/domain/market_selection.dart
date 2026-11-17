import 'package:decimal/decimal.dart';

import 'market_quote.dart';

enum MarketSort { symbol, funding, volume, openInterest, price, change }

class MarketSelection {
  const MarketSelection({
    this.query = '',
    this.onlyFavorites = false,
    this.sort,
    this.descending = true,
  });
  final String query;
  final bool onlyFavorites;

  /// Null keeps the exchange catalog order.
  final MarketSort? sort;
  final bool descending;
}

/// Open interest valued in the quote asset at the mark price.
Decimal? openInterestValue(MarketQuote quote, Decimal? openInterest) =>
    openInterest == null || quote.markPrice == null ? null : openInterest * quote.markPrice!;

List<MarketQuote> selectMarkets(
  Iterable<MarketQuote> quotes,
  MarketSelection selection,
  Set<String> favorites, {
  Map<String, Decimal> openInterest = const {},
}) {
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
        (quote) => (!selection.onlyFavorites || favorites.contains(quote.symbol)) && matches(quote),
      )
      .toList();
  if (selection.sort case final sort?) {
    Comparable<dynamic>? key(MarketQuote quote) => switch (sort) {
      MarketSort.symbol => quote.symbol,
      MarketSort.funding => quote.funding,
      MarketSort.volume => quote.quoteVolume,
      MarketSort.openInterest => openInterestValue(quote, openInterest[quote.symbol]),
      MarketSort.price => quote.price,
      MarketSort.change => quote.change,
    };
    final order = {for (var i = 0; i < filtered.length; i++) filtered[i].symbol: i};
    // Unknown values stay last in either direction; ties keep catalog order.
    filtered.sort((a, b) {
      final x = key(a), y = key(b);
      final byValue = x == null || y == null
          ? (x == null ? (y == null ? 0 : 1) : -1)
          : selection.descending
          ? y.compareTo(x)
          : x.compareTo(y);
      return byValue != 0 ? byValue : order[a.symbol]!.compareTo(order[b.symbol]!);
    });
  }
  // Exact identities precede partial labels, retaining the stable metadata
  // (or chosen sort) order within each group. Price updates never cause
  // default row jumps.
  return List.unmodifiable([...filtered.where(exact), ...filtered.where((quote) => !exact(quote))]);
}

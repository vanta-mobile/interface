import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/market_quote.dart';
import '../domain/market_selection.dart';
import 'market_providers.dart';
import 'open_interest_provider.dart';
import 'selection_providers.dart';

final marketSelectionProvider =
    NotifierProvider.autoDispose<MarketSelectionController, MarketSelection>(
      MarketSelectionController.new,
    );

class MarketSelectionController extends Notifier<MarketSelection> {
  @override
  MarketSelection build() => const MarketSelection();
  void search(String query) => state = MarketSelection(
    query: query,
    onlyFavorites: state.onlyFavorites,
    sort: state.sort,
    descending: state.descending,
  );
  void favorites(bool onlyFavorites) => state = MarketSelection(
    query: state.query,
    onlyFavorites: onlyFavorites,
    sort: state.sort,
    descending: state.descending,
  );

  /// Cycles a column through descending, ascending and the catalog order.
  /// Symbols start ascending, as alphabetical order reads naturally.
  void sortBy(MarketSort sort) {
    final first = sort != MarketSort.symbol;
    final (next, descending) = state.sort != sort
        ? (sort, first)
        : state.descending == first
        ? (sort, !first)
        : (null, true);
    state = MarketSelection(
      query: state.query,
      onlyFavorites: state.onlyFavorites,
      sort: next,
      descending: descending,
    );
  }
}

final selectedMarketsProvider = Provider.autoDispose<AsyncValue<List<MarketQuote>>>((ref) {
  final feed = ref.watch(liveMarketQuotesProvider);
  final selection = ref.watch(marketSelectionProvider);
  final favorites = ref.watch(favoriteSymbolsProvider);
  final openInterest = selection.sort == MarketSort.openInterest
      ? ref.watch(openInterestCacheProvider)
      : const <String, Decimal>{};
  return feed.whenData(
    (value) => selectMarkets(value.quotes, selection, favorites, openInterest: openInterest),
  );
});

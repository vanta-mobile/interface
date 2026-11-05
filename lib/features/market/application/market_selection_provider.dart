import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/market_descriptor.dart';
import '../domain/market_quote.dart';
import '../domain/market_selection.dart';
import 'market_providers.dart';
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
    category: state.category,
    onlyFavorites: state.onlyFavorites,
  );
  void category(MarketCategory category) => state = MarketSelection(
    query: state.query,
    category: category,
    onlyFavorites: state.onlyFavorites,
  );
  void favorites(bool onlyFavorites) => state = MarketSelection(
    query: state.query,
    category: state.category,
    onlyFavorites: onlyFavorites,
  );
}

final selectedMarketsProvider = Provider.autoDispose<AsyncValue<List<MarketQuote>>>((ref) {
  final feed = ref.watch(liveMarketQuotesProvider);
  final selection = ref.watch(marketSelectionProvider);
  final favorites = ref.watch(favoriteSymbolsProvider);
  return feed.whenData((value) => selectMarkets(value.quotes, selection, favorites));
});

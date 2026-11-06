import '../../../../core/market_failure.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/application/market_selection_provider.dart';
import '../../../market/domain/market_quote.dart';
import '../../../market/domain/market_descriptor.dart';
import '../../application/providers.dart';
import 'market_list_row.dart';
import 'market_quote_status.dart';
import 'market_search_controls.dart';
import 'primitives.dart';

class MarketSheet extends ConsumerWidget {
  const MarketSheet({super.key, this.embedded = false, this.onSelect});
  final bool embedded;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instruments = ref.watch(liveMarketQuotesProvider);
    final favorites = ref.watch(favoriteSymbolsProvider);
    final results = ref.watch(selectedMarketsProvider);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(context, 'selectMarket'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        const MarketSearchControls(),
        const SizedBox(height: 8),
        MutedText(
          l10n.marketResultsCount(
            results.value?.length ?? 0,
            instruments.value?.quotes.length ?? 0,
          ),
        ),
        if (instruments.value case final quotes?)
          MarketQuoteStatus(
            quotes: quotes,
            onRetry: () => ref.read(quoteReconnectProvider.notifier).reconnect(),
          ),
        const SizedBox(height: 6),
        SizedBox(
          height: embedded ? 520 : MediaQuery.sizeOf(context).height * .5,
          child: _results(context, ref, results, favorites),
        ),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MarketQuote>> instruments,
    Set<String> favorites,
  ) {
    return instruments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error is MarketFailure ? error.displayMessage : tr(context, 'marketUnavailable')),
            TextButton(
              onPressed: () {
                ref.invalidate(instrumentsProvider);
                ref.invalidate(liveMarketQuotesProvider);
              },
              child: Text(tr(context, 'retry')),
            ),
          ],
        ),
      ),
      data: (ranked) {
        final selection = ref.watch(marketSelectionProvider);
        if (ranked.isEmpty) {
          return Center(
            child: Text(
              selection.onlyFavorites && favorites.isEmpty
                  ? tr(context, 'emptyFavorites')
                  : selection.category != MarketCategory.all && selection.query.trim().isEmpty
                  ? AppLocalizations.of(context).marketNoCategoryResults
                  : tr(context, 'noMarketsFound'),
            ),
          );
        }
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: ranked.length,
          itemBuilder: (context, index) => MarketListRow(
            key: ValueKey('market-${ranked[index].symbol}'),
            quote: ranked[index],
            onSelect: () {
              ref.read(symbolProvider.notifier).select(ranked[index].symbol);
              ref.read(orderPriceProvider.notifier).setPrice('');
              if (!embedded) Navigator.pop(context);
              onSelect?.call();
            },
          ),
        );
      },
    );
  }
}

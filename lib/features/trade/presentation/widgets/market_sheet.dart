import '../trade_theme.dart';
import '../../application/page_refresh_provider.dart';
import '../../../../core/market_failure.dart';
import '../../../../core/presentation/status_view.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/application/market_selection_provider.dart';
import '../../../market/domain/market_quote.dart';
import '../../application/providers.dart';
import 'favorite_toggle.dart';
import 'market_list_row.dart';
import 'market_list_skeleton.dart';
import 'market_quote_status.dart';
import 'market_search_controls.dart';
import 'primitives.dart';

void openMarketSelector(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const _MarketSelectorPage()));

class _MarketSelectorPage extends ConsumerWidget {
  const _MarketSelectorPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: TradeColors.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 500 || MediaQuery.textScalerOf(context).scale(12) > 18) {
            return const SingleChildScrollView(padding: EdgeInsets.all(16), child: MarketSheet());
          }
          return const Padding(padding: EdgeInsets.all(16), child: MarketSheet(fullscreen: true));
        },
      ),
    ),
  );
}

class MarketSheet extends ConsumerWidget {
  const MarketSheet({super.key, this.embedded = false, this.fullscreen = false, this.onSelect});
  final bool embedded, fullscreen;
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
        Row(
          children: [
            Expanded(child: Text(tr(context, 'selectMarket'), style: TradeTypography.heading)),
            if (!embedded)
              IconButton(
                key: const Key('close-market-selector'),
                tooltip: l10n.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: TradeColors.text),
              ),
          ],
        ),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  '${l10n.tradeSymbols}\n${tr(context, 'fundingRate')}',
                  style: TradeTypography.small,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '${tr(context, 'volume24h')}\nUSDT',
                  textAlign: TextAlign.right,
                  style: TradeTypography.small,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  '${tr(context, 'price')}\n${tr(context, 'change')}',
                  textAlign: TextAlign.right,
                  style: TradeTypography.small,
                ),
              ),
            ],
          ),
        ),
        if (fullscreen)
          Expanded(child: _refresh(context, ref, results, favorites))
        else
          SizedBox(
            height: embedded ? 520 : MediaQuery.sizeOf(context).height * .5,
            child: _refresh(context, ref, results, favorites),
          ),
      ],
    );
  }

  Widget _refresh(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MarketQuote>> results,
    Set<String> favorites,
  ) => RefreshIndicator(
    onRefresh: () async {
      final markets = ref.read(pageRefreshProvider).markets();
      // Joins the watchlist read that [markets] starts; reports its failure.
      final failure = await ref.read(favoriteSymbolsProvider.notifier).refresh();
      await markets;
      if (failure != null && context.mounted) showFavoriteFailure(context, failure);
    },
    child: _results(context, ref, results, favorites),
  );

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MarketQuote>> instruments,
    Set<String> favorites,
  ) {
    return instruments.when(
      loading: () => const MarketListSkeleton(),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StatusFailureView(
            message: error is MarketFailure ? error.displayMessage : null,
            onRetry: () async {
              ref.invalidate(instrumentsProvider);
              ref.invalidate(liveMarketQuotesProvider);
              // Settles on the first catalog/quote event, including a new failure.
              await ref.read(liveMarketQuotesProvider.future);
            },
          ),
        ],
      ),
      data: (ranked) {
        final selection = ref.watch(marketSelectionProvider);
        if (ranked.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (selection.onlyFavorites && favorites.isEmpty)
                StatusEmptyView(title: tr(context, 'emptyFavorites'))
              else
                StatusEmptyView(
                  title: l10n.statusNoResultsTitle,
                  message: l10n.statusNoResultsMessage,
                ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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

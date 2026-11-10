import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../trade_theme.dart';
import '../../../market/application/market_selection_provider.dart';
import '../../../market/domain/market_descriptor.dart';

class MarketCategoryFilter extends ConsumerWidget {
  const MarketCategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(marketSelectionProvider.select((state) => state.category));
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.marketCategories,
      child: SingleChildScrollView(
        key: const Key('market-category-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in MarketCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('market-category-${category.name}'),
                  label: Text(_label(l10n, category)),
                  selected: selected == category,
                  showCheckmark: false,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: TradeColors.card,
                  selectedColor: TradeColors.accentBackground,
                  labelStyle: TradeTypography.body.copyWith(
                    color: selected == category ? TradeColors.accent : TradeColors.muted,
                  ),
                  onSelected: (_) => ref.read(marketSelectionProvider.notifier).category(category),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, MarketCategory category) => switch (category) {
    MarketCategory.all => l10n.marketCategoryAll,
    MarketCategory.top => l10n.marketCategoryTop,
    MarketCategory.rwa => l10n.marketCategoryRwa,
    MarketCategory.meme => l10n.marketCategoryMeme,
    MarketCategory.ai => l10n.marketCategoryAi,
    MarketCategory.preLaunch => l10n.marketCategoryPreLaunch,
    MarketCategory.stocks => l10n.marketCategoryStocks,
    MarketCategory.etf => l10n.marketCategoryEtf,
    MarketCategory.commodities => l10n.marketCategoryCommodities,
    MarketCategory.semiconductors => l10n.marketCategorySemiconductors,
  };
}

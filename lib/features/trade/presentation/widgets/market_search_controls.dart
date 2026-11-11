import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../trade_theme.dart';
import '../../../market/application/market_selection_provider.dart';

class MarketSearchControls extends ConsumerStatefulWidget {
  const MarketSearchControls({super.key});
  @override
  ConsumerState<MarketSearchControls> createState() => _MarketSearchControlsState();
}

class _MarketSearchControlsState extends ConsumerState<MarketSearchControls> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(marketSelectionProvider);
    final controller = ref.read(marketSelectionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('market-search'),
          controller: search,
          onChanged: controller.search,
          decoration: InputDecoration(
            hintText: tr(context, 'search'),
            fillColor: TradeColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: tr(context, 'clearSearch'),
                    onPressed: () {
                      search.clear();
                      controller.search('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            key: const Key('market-list-filter'),
            children: [
              for (final favorite in [true, false])
                InkWell(
                  onTap: () => controller.favorites(favorite),
                  child: Semantics(
                    selected: selection.onlyFavorites == favorite,
                    button: true,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        border: selection.onlyFavorites == favorite
                            ? const Border(bottom: BorderSide(color: TradeColors.accent))
                            : null,
                      ),
                      child: Text(
                        favorite
                            ? tr(context, 'favorites')
                            : AppLocalizations.of(context).tradeFutures,
                        style: TradeTypography.body.copyWith(
                          color: selection.onlyFavorites == favorite
                              ? TradeColors.text
                              : TradeColors.muted,
                          fontWeight: selection.onlyFavorites == favorite
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                tr(context, 'spot'),
                style: TradeTypography.body.copyWith(color: TradeColors.muted),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TradeColors.card,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tr(context, 'comingSoon'),
                  style: TradeTypography.small.copyWith(color: TradeColors.secondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

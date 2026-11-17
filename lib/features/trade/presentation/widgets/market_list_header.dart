import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/market_selection_provider.dart';
import '../../../market/domain/market_selection.dart';
import '../trade_theme.dart';

/// Column titles of the market list; each title sorts by its own value.
class MarketListHeader extends StatelessWidget {
  const MarketListHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget column(List<(String, MarketSort)> titles, {bool end = false}) => Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [for (final (label, sort) in titles) _SortTitle(label: label, sort: sort)],
    );
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: column([
            (l10n.tradeSymbols, MarketSort.symbol),
            (tr(context, 'fundingRate'), MarketSort.funding),
          ]),
        ),
        Expanded(
          flex: 4,
          child: column([
            (tr(context, 'volume24h'), MarketSort.volume),
            (l10n.marketOpenInterest, MarketSort.openInterest),
          ], end: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: column([
            (tr(context, 'price'), MarketSort.price),
            (tr(context, 'change'), MarketSort.change),
          ], end: true),
        ),
      ],
    );
  }
}

class _SortTitle extends ConsumerWidget {
  const _SortTitle({required this.label, required this.sort});
  final String label;
  final MarketSort sort;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (active, descending) = ref.watch(
      marketSelectionProvider.select((s) => (s.sort == sort, s.descending)),
    );
    return Semantics(
      button: true,
      selected: active,
      label: AppLocalizations.of(context).marketSortBy(label),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('market-sort-${sort.name}'),
        onTap: () => ref.read(marketSelectionProvider.notifier).sortBy(sort),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, style: TradeTypography.small)),
              Icon(
                !active
                    ? Icons.unfold_more_rounded
                    : descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 12,
                color: active ? TradeColors.accent : TradeColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

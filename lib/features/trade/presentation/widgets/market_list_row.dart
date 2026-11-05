import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/application/selection_providers.dart';
import '../../../market/domain/market.dart';
import '../../../market/domain/market_quote.dart';
import 'primitives.dart';

class MarketListRow extends ConsumerWidget {
  const MarketListRow({super.key, required this.quote, required this.onSelect});
  final MarketQuote quote;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoriteSymbolsProvider.select((s) => s.contains(quote.symbol)));
    final selected = ref.watch(symbolProvider.select((s) => s == quote.symbol));
    final funding = quote.funding == null ? null : quote.funding! * Decimal.fromInt(100);
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  CoinIcon(base: quote.base, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${quote.base} / USDT', style: Theme.of(context).textTheme.titleSmall),
                        if (quote.descriptor.name.isNotEmpty && quote.descriptor.name != quote.base)
                          Text(quote.descriptor.name, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 16),
                  IconButton(
                    key: ValueKey('favorite-${quote.symbol}'),
                    tooltip:
                        '${tr(context, favorite ? 'removeFavorite' : 'addFavorite')} ${quote.symbol}',
                    isSelected: favorite,
                    onPressed: () =>
                        ref.read(favoriteSymbolsProvider.notifier).toggle(quote.symbol),
                    icon: const Icon(Icons.star_border_rounded),
                    selectedIcon: const Icon(Icons.star_rounded, color: AppColors.accent),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      tr(context, 'lastPrice'),
                      quote.price == null
                          ? '—'
                          : marketNumber(
                              quote.price!,
                              minimumDecimals: quote.precision.priceDecimals,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      tr(context, 'change'),
                      _percent(quote.change, 2),
                      color: _color(quote.change),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _Metric(tr(context, 'volume24h'), _volume(quote.quoteVolume))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Metric(
                      tr(context, 'fundingRate'),
                      _percent(funding, 4),
                      color: _color(funding),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }

  static Color _color(Decimal? value) => value == null || value == Decimal.zero
      ? AppColors.secondary
      : value > Decimal.zero
      ? AppColors.positive
      : AppColors.negative;

  static String _percent(Decimal? value, int places) =>
      value == null ? '—' : '${value > Decimal.zero ? '+' : ''}${value.toStringAsFixed(places)}%';

  static String _volume(Decimal? value) {
    if (value == null) return '—';
    for (final (factor, suffix) in [(1000000000, 'B'), (1000000, 'M'), (1000, 'K')]) {
      if (value >= Decimal.fromInt(factor)) {
        final scaled = (value / Decimal.fromInt(factor)).toDecimal(scaleOnInfinitePrecision: 2);
        return '${scaled.toStringAsFixed(2)}$suffix USDT';
      }
    }
    return '${value.toStringAsFixed(2)} USDT';
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color, this.alignEnd = false});
  final String label, value;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      SelectableText(
        value,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: color ?? AppColors.text, fontSize: 12),
      ),
    ],
  );
}

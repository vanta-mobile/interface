import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/motion/animated_number_text.dart';
import '../../../market/application/open_interest_provider.dart';
import '../../../market/application/public_leverage_provider.dart';
import '../../../market/application/selection_providers.dart';
import '../../../market/domain/market.dart';
import '../../../market/domain/market_quote.dart';
import '../../../market/domain/market_selection.dart';
import '../trade_theme.dart';
import 'favorite_toggle.dart';
import 'max_leverage_badge.dart';
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
    final leverage = ref.watch(
      publicLeverageProvider.select((s) => s.value?[quote.symbol]?.maximumLeverage),
    );
    final openInterest = openInterestValue(
      quote,
      ref.watch(openInterestProvider(quote.symbol)).value,
    );
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onSelect,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: IconButton(
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 44),
                          key: ValueKey('favorite-${quote.symbol}'),
                          tooltip:
                              '${tr(context, favorite ? 'removeFavorite' : 'addFavorite')} ${quote.symbol}',
                          isSelected: favorite,
                          padding: EdgeInsets.zero,
                          // Flush with the Symbols header and tabs above.
                          alignment: AlignmentDirectional.centerStart,
                          onPressed: () => toggleFavorite(context, ref, quote.symbol),
                          icon: const Icon(
                            Icons.star_border_rounded,
                            size: 18,
                            color: TradeColors.muted,
                          ),
                          selectedIcon: const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: TradeColors.accent,
                          ),
                        ),
                      ),
                      CoinIcon(base: quote.base, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.symbol,
                              style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (quote.descriptor.name.isNotEmpty &&
                                quote.descriptor.name != quote.base)
                              Text(quote.descriptor.name, style: TradeTypography.small),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (leverage != null) ...[
                                  MaxLeverageBadge(leverage),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: _FittingNumber(
                                    _percent(funding, 4),
                                    style: TradeTypography.small,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _FittingNumber(
                        _volume(quote.quoteVolume),
                        textAlign: TextAlign.right,
                        style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      _FittingNumber(
                        _volume(openInterest),
                        textAlign: TextAlign.right,
                        style: TradeTypography.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _FittingNumber(
                        quote.price == null
                            ? '—'
                            : marketNumber(
                                quote.price!,
                                minimumDecimals: quote.precision.priceDecimals,
                              ),
                        textAlign: TextAlign.right,
                        style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      _FittingNumber(
                        _percent(quote.change, 2),
                        textAlign: TextAlign.right,
                        style: TradeTypography.small.copyWith(color: _color(quote.change)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _color(Decimal? value) => value == null || value == Decimal.zero
      ? TradeColors.muted
      : value > Decimal.zero
      ? TradeColors.accent
      : TradeColors.negative;
  static String _percent(Decimal? value, int places) =>
      value == null ? '—' : '${value > Decimal.zero ? '+' : ''}${value.toStringAsFixed(places)}%';
  // The catalog admits only USDT-quoted perpetuals; the product shows USDT
  // amounts as dollars.
  static String _volume(Decimal? value) =>
      value == null ? '—' : '\$${marketNumber(Decimal.parse(value.toStringAsFixed(0)))}';
}

class _FittingNumber extends StatelessWidget {
  const _FittingNumber(this.value, {this.style, this.textAlign});
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: textAlign == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
    child: AnimatedNumberText(value, style: style, textAlign: textAlign),
  );
}

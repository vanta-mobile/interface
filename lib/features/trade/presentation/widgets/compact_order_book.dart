import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/navigation_provider.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'book_skeleton.dart';
import 'favorite_toggle.dart';
import 'book_feed_state.dart';
import 'order_book_row.dart';
import 'trade_funding.dart';
import 'trade_icon.dart';
import 'trade_option_sheet.dart';

/// Trade-workspace order book column from the Futures design. Shows eight
/// levels per side, or six while the compact K-line is open above it.
class CompactOrderBook extends ConsumerStatefulWidget {
  const CompactOrderBook({super.key});
  @override
  ConsumerState<CompactOrderBook> createState() => _CompactOrderBookState();
}

class _CompactOrderBookState extends ConsumerState<CompactOrderBook> {
  bool quoteSize = true;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(bookProvider);
    final book = feed.isReloading ? null : feed.value;
    final market = ref.watch(currentMarketProvider);
    final precision =
        market?.precision ?? ref.watch(selectedPrecisionProvider) ?? const MarketPrecision();
    final symbol = ref.watch(symbolProvider);
    final base = market?.base ?? symbol.replaceAll('USDT', '');
    final depth = ref.watch(tradeKlineVisibleProvider) ? 6 : 8;
    final asks = book?.asks.take(depth).toList() ?? <BookLevel>[];
    final bids = book?.bids.take(depth).toList() ?? <BookLevel>[];
    final maximum = [...asks, ...bids].map((level) => level.quantity).fold(0.0, math.max);
    final total = math.max(
      asks.fold(0.0, (sum, e) => sum + e.quantity),
      bids.fold(0.0, (sum, e) => sum + e.quantity),
    );
    List<double> running(List<BookLevel> levels) {
      var sum = 0.0;
      return [for (final level in levels) total <= 0 ? 0 : (sum += level.quantity) / total];
    }

    final askDepth = running(asks), bidDepth = running(bids);
    // Rows are keyed by slot, not price, so depth bars ease between levels
    // as the book moves instead of popping in with each new price.
    OrderBookRow row(int slot, BookLevel level, bool buy, double share) => OrderBookRow(
      key: ValueKey('$symbol/${buy ? 'bid' : 'ask'}/$slot'),
      level: level,
      buy: buy,
      maximum: maximum,
      precision: precision,
      compact: true,
      cumulative: share,
      quoteSize: quoteSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BookTools(symbol: symbol),
        const TradeFunding(),
        const SizedBox(height: 8),
        _BookHeader(
          quoteSize: quoteSize,
          base: base,
          onUnit: (value) => setState(() => quoteSize = value),
        ),
        const SizedBox(height: 12),
        if (book == null || (book.asks.isEmpty && book.bids.isEmpty))
          BookFeedState(
            feed: feed,
            loading: const BookSkeleton.compact(key: Key('order-book-skeleton')),
          )
        else ...[
          for (var i = asks.length - 1; i >= 0; i--) row(i, asks[i], false, askDepth[i]),
          const SizedBox(height: 8),
          _LastPrice(market: market),
          const SizedBox(height: 8),
          for (var i = 0; i < bids.length; i++) row(i, bids[i], true, bidDepth[i]),
          const SizedBox(height: 8),
          _BookRatio(book: book),
        ],
      ],
    );
  }
}

class _BookTools extends ConsumerWidget {
  const _BookTools({required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoriteSymbolsProvider).contains(symbol);
    final kline = ref.watch(tradeKlineVisibleProvider);
    Widget tool({
      required Key key,
      required String tooltip,
      required bool selected,
      required VoidCallback onPressed,
      required Widget icon,
    }) => Semantics(
      selected: selected,
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-6, 0),
          child: tool(
            key: const Key('trade-book-favorite'),
            tooltip: '${tr(context, favorite ? 'removeFavorite' : 'addFavorite')} $symbol',
            selected: favorite,
            onPressed: () => toggleFavorite(context, ref, symbol),
            icon: TradeIcon(
              'favorite',
              size: 16,
              color: favorite ? TradeColors.accent : TradeColors.muted,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(-2, 0),
          child: tool(
            key: const Key('trade-kline-toggle'),
            tooltip: AppLocalizations.of(context).quickOrderChartTab,
            selected: kline,
            onPressed: ref.read(tradeKlineVisibleProvider.notifier).toggle,
            icon: TradeIcon(
              kline ? 'chart-on' : 'chart-off',
              size: 13.33,
              color: kline ? TradeColors.text : TradeColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.quoteSize, required this.base, required this.onUnit});
  final bool quoteSize;
  final String base;
  final ValueChanged<bool> onUnit;
  @override
  Widget build(BuildContext context) {
    final unit = quoteSize ? 'USDT' : base;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${tr(context, 'price')}\nUSDT', style: TradeTypography.small),
        const SizedBox(width: 4),
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: InkWell(
              key: const Key('trade-book-size-unit'),
              onTap: () async {
                final value = await showTradeOptionSheet(
                  context,
                  title: AppLocalizations.of(context).tradeSelectUnitType,
                  selected: quoteSize,
                  options: [
                    (value: true, label: 'USDT', description: null),
                    (value: false, label: base, description: null),
                  ],
                );
                if (value != null) onUnit(value);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr(context, 'quantity'), style: TradeTypography.small),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          unit,
                          style: TradeTypography.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 12, color: TradeColors.muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LastPrice extends StatelessWidget {
  const _LastPrice({required this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) {
    String price(Object value) =>
        marketNumber(value, minimumDecimals: market!.precision.priceDecimals);
    return Column(
      key: const Key('trade-book-last-price'),
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            market == null ? '—' : price(market!.price),
            style: TradeTypography.heading.copyWith(
              color: (market?.change ?? 0) >= 0 ? TradeColors.accent : TradeColors.negative,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Tooltip(
          message: tr(context, 'mark'),
          child: Text(
            market == null
                ? '—'
                // Mark arrives unrounded; show it at the symbol's price precision.
                : price(market!.mark.toStringAsFixed(market!.precision.priceDecimals)),
            style: TradeTypography.small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BookRatio extends StatelessWidget {
  const _BookRatio({required this.book});
  final OrderBook book;
  @override
  Widget build(BuildContext context) {
    final buys = book.bids.fold(0.0, (sum, e) => sum + e.quantity);
    final sells = book.asks.fold(0.0, (sum, e) => sum + e.quantity);
    final ratio = buys + sells == 0 ? .5 : buys / (buys + sells);
    final buyPercent = (ratio * 100).round();
    Widget bar(Color color, double share) => Expanded(
      flex: (share * 1000).round().clamp(1, 999),
      child: Container(
        height: 3,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
      ),
    );
    return Column(
      key: const Key('trade-book-ratio'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            bar(TradeColors.ratioBuy, ratio),
            const SizedBox(width: 2),
            bar(TradeColors.ratioSell, 1 - ratio),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 4,
          children: [
            Text(
              'B $buyPercent%',
              style: TradeTypography.small.copyWith(color: TradeColors.positive),
            ),
            Text(
              'S ${100 - buyPercent}%',
              style: TradeTypography.small.copyWith(color: TradeColors.negative),
            ),
          ],
        ),
      ],
    );
  }
}

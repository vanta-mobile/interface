import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
import 'measured_height.dart';
import 'trade_icon.dart';
import 'trade_option_sheet.dart';

/// Trade-workspace order book column from the Futures design. Starts with
/// eight levels per side (six while the compact K-line is open); beside the
/// order form it adds or removes levels, the same on both sides, so its
/// bottom stays close to the form's.
class CompactOrderBook extends ConsumerStatefulWidget {
  const CompactOrderBook({super.key, this.targetHeight});

  /// Height to approach, e.g. the order form's; null keeps the default depth.
  final ValueListenable<double?>? targetHeight;
  @override
  ConsumerState<CompactOrderBook> createState() => _CompactOrderBookState();
}

class _CompactOrderBookState extends ConsumerState<CompactOrderBook> {
  bool quoteSize = true;
  static const _minDepth = 3, _maxDepth = 20;
  int? _depth;
  int _shown = 0;
  double? _height, _rowHeight, _fitTarget, _pairHeight;
  int _fitSteps = 0;

  /// The last laid-out (levels per side, height), to measure a pair's height.
  (int, double)? _sample;

  @override
  void initState() {
    super.initState();
    widget.targetHeight?.addListener(_fit);
  }

  @override
  void didUpdateWidget(CompactOrderBook old) {
    super.didUpdateWidget(old);
    if (old.targetHeight != widget.targetHeight) {
      old.targetHeight?.removeListener(_fit);
      widget.targetHeight?.addListener(_fit);
    }
  }

  @override
  void dispose() {
    widget.targetHeight?.removeListener(_fit);
    super.dispose();
  }

  /// Each side gains or loses whole level pairs until the book is no taller
  /// than the target and less than one pair short of it. A pair's height is
  /// measured from two laid-out depths (first estimated from one row), so the
  /// depth settles instead of oscillating; adjustments per target are capped.
  void _fit() {
    final target = widget.targetHeight?.value, height = _height, row = _rowHeight;
    if (!mounted || target == null || height == null || row == null || row <= 0 || _shown == 0) {
      return;
    }
    if (_sample case (final shown, final measured) when shown != _shown) {
      final pair = (height - measured) / (_shown - shown);
      if (pair > 0) _pairHeight = pair;
    }
    _sample = (_shown, height);
    if (target != _fitTarget) {
      _fitTarget = target;
      _fitSteps = 0;
    }
    final change = ((target - height) / (_pairHeight ?? 2 * row)).floor();
    if (change == 0 || _fitSteps >= 6) return;
    final next = (_shown + change).clamp(_minDepth, _maxDepth);
    if (next == _depth) return;
    _fitSteps++;
    setState(() => _depth = next);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(bookProvider);
    final book = feed.isReloading ? null : feed.value;
    final market = ref.watch(currentMarketProvider);
    final precision =
        market?.precision ?? ref.watch(selectedPrecisionProvider) ?? const MarketPrecision();
    final symbol = ref.watch(symbolProvider);
    final base = market?.base ?? symbol.replaceAll('USDT', '');
    final kline = ref.watch(tradeKlineVisibleProvider);
    final depth = kline || widget.targetHeight == null ? (kline ? 6 : 8) : _depth ?? 8;
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
    _shown = math.max(asks.length, bids.length);
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
    final column = Column(
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
          for (var i = 0; i < bids.length; i++)
            if (i == 0)
              MeasuredHeight(
                onHeight: (value) {
                  _rowHeight = value;
                  _fit();
                },
                child: row(i, bids[i], true, bidDepth[i]),
              )
            else
              row(i, bids[i], true, bidDepth[i]),
          const SizedBox(height: 8),
          _BookRatio(book: book),
        ],
      ],
    );
    if (widget.targetHeight == null) return column;
    return MeasuredHeight(
      onHeight: (value) {
        _height = value;
        _fit();
      },
      child: column,
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
            // Same star as the market list: filled accent once favourited.
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18,
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

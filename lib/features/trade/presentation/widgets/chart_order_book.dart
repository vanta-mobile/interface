import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'book_skeleton.dart';
import 'order_book.dart';
import 'order_book_row.dart';

/// The chart page consumes the same shared public feed as the trade book.
class ChartOrderBook extends ConsumerWidget {
  const ChartOrderBook({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(bookProvider);
    final book = feed.isReloading ? null : feed.value;
    final precision = ref.watch(selectedPrecisionProvider);
    final asks = book?.asks.take(12).toList() ?? <BookLevel>[];
    final bids = book?.bids.take(12).toList() ?? <BookLevel>[];
    final maximum = [...asks, ...bids].fold(0.0, (v, l) => math.max(v, l.quantity));
    final base = ref.watch(symbolProvider).replaceAll('USDT', '');
    return Column(
      key: const Key('chart-order-book'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'book'),
          style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text('${tr(context, 'quantity')} ($base)', style: TradeTypography.small),
            ),
            Expanded(
              child: Text(
                '${tr(context, 'price')} (USDT)',
                textAlign: TextAlign.right,
                style: TradeTypography.small,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('${tr(context, 'price')} (USDT)', style: TradeTypography.small)),
            Expanded(
              child: Text(
                '${tr(context, 'quantity')} ($base)',
                textAlign: TextAlign.right,
                style: TradeTypography.small,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (book == null || asks.isEmpty && bids.isEmpty)
          BookFeedState(
            feed: feed,
            loading: const BookSkeleton.split(key: Key('chart-order-book-skeleton')),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (final level in bids)
                      OrderBookRow(
                        level: level,
                        buy: true,
                        maximum: maximum,
                        precision: precision,
                        compact: true,
                        reversed: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (final level in asks)
                      OrderBookRow(
                        level: level,
                        buy: false,
                        maximum: maximum,
                        precision: precision,
                        compact: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        const Divider(color: TradeColors.line),
        const SizedBox(height: 16),
        Text(
          tr(context, 'trades'),
          style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('${tr(context, 'price')} (USDT)', style: TradeTypography.small)),
            Expanded(
              child: Text(
                '${tr(context, 'quantity')} ($base)',
                textAlign: TextAlign.right,
                style: TradeTypography.small,
              ),
            ),
            Expanded(
              child: Text(
                tr(context, 'time'),
                textAlign: TextAlign.right,
                style: TradeTypography.small,
              ),
            ),
          ],
        ),
        if (book?.trades.isNotEmpty != true)
          BookFeedState(
            feed: feed,
            loading: const BookSkeleton.trades(key: Key('chart-trades-skeleton')),
            // A connected feed without trades is still waiting for its first fill.
            empty: const BookSkeleton.trades(key: Key('chart-trades-skeleton')),
          )
        else
          for (final (index, trade) in book!.trades.take(10).indexed)
            Padding(
              // These stateless rows represent display slots. A timestamp is
              // not unique: multiple fills can arrive in the same millisecond.
              key: ValueKey('chart-trade/$base/$index'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      marketNumber(trade.price, minimumDecimals: precision.priceDecimals),
                      style: TradeTypography.small.copyWith(
                        color: trade.buy ? TradeColors.accent : TradeColors.negative,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      marketNumber(trade.quantity, minimumDecimals: precision.quantityDecimals),
                      textAlign: TextAlign.right,
                      style: TradeTypography.small.copyWith(color: TradeColors.text),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _time(trade.time),
                      textAlign: TextAlign.right,
                      style: TradeTypography.small.copyWith(color: TradeColors.text),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _time(int milliseconds) {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds).toUtc();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

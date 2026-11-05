import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/providers.dart';
import '../../../market/domain/market.dart';
import '../../../market/application/market_providers.dart';
import 'primitives.dart';
import 'order_book_row.dart';

class OrderBookPanel extends ConsumerStatefulWidget {
  const OrderBookPanel({super.key});
  @override
  ConsumerState<OrderBookPanel> createState() => _OrderBookPanelState();
}

class _OrderBookPanelState extends ConsumerState<OrderBookPanel> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(bookProvider);
    final book = feed.value;
    final market = ref.watch(currentMarketProvider);
    final exchangePrecision = ref.watch(selectedPrecisionProvider);
    final precision = market?.precision ?? exchangePrecision;
    final asks = book?.asks.take(8).toList() ?? <BookLevel>[];
    final bids = book?.bids.take(8).toList() ?? <BookLevel>[];
    final maximum = [...asks, ...bids].map((level) => level.quantity).fold(0.0, math.max);
    final symbol = ref.watch(symbolProvider);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
            child: TabChoices(
              items: [tr(context, 'book'), tr(context, 'trades')],
              selected: tab,
              onSelect: (v) => setState(() => tab = v),
              underlined: true,
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
            child: Row(
              children: [
                Expanded(child: MutedText('${tr(context, 'price')}\n(USDT)', size: 9)),
                Expanded(
                  child: Text(
                    '${tr(context, 'quantity')}\n(${market?.base ?? ref.watch(symbolProvider).replaceAll('USDT', '')})',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: AppColors.muted, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          if (book == null || (book.asks.isEmpty && book.bids.isEmpty))
            SizedBox(
              height: 430,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    tr(
                      context,
                      book?.connected == false || feed.hasError ? 'bookError' : 'bookWaiting',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                  ),
                ),
              ),
            )
          else if (tab == 0) ...[
            for (final level in asks.reversed)
              OrderBookRow(
                key: ValueKey('$symbol/ask/${level.price}'),
                level: level,
                buy: false,
                maximum: maximum,
                precision: precision,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    market == null
                        ? '—'
                        : marketNumber(
                            market.price,
                            minimumDecimals: market.precision.priceDecimals,
                          ),
                    style: TextStyle(
                      fontSize: 17,
                      color: (market?.change ?? 0) >= 0 ? AppColors.positive : AppColors.negative,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 11, color: AppColors.warning),
                      const SizedBox(width: 3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MutedText(
                            market == null
                                ? '—'
                                : marketNumber(
                                    market.mark,
                                    minimumDecimals: market.precision.priceDecimals,
                                  ),
                            size: 10,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (final level in bids)
              OrderBookRow(
                key: ValueKey('$symbol/bid/${level.price}'),
                level: level,
                buy: true,
                maximum: maximum,
                precision: precision,
              ),
            _BookRatio(book: book),
          ] else if (book.trades.isEmpty)
            SizedBox(
              height: 430,
              child: Center(
                child: Text(
                  tr(context, 'noTrades'),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            )
          else ...[
            for (final trade in book.trades.take(18))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          marketNumber(trade.price, minimumDecimals: precision.priceDecimals),
                          style: TextStyle(
                            fontSize: 10,
                            color: trade.buy ? AppColors.positive : AppColors.negative,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          marketNumber(trade.quantity, minimumDecimals: precision.quantityDecimals),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: book?.connected == true ? AppColors.accent : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    tr(context, book?.connected == true ? 'marketSource' : 'retry'),
                    style: const TextStyle(fontSize: 8, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 2),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'B ${(ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 8, color: AppColors.positive),
              ),
              Text(
                '${((1 - ratio) * 100).toStringAsFixed(0)}% S',
                style: const TextStyle(fontSize: 8, color: AppColors.negative),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              children: [
                Expanded(
                  flex: (ratio * 1000).round().clamp(1, 999),
                  child: const SizedBox(height: 3, child: ColoredBox(color: AppColors.positive)),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: ((1 - ratio) * 1000).round().clamp(1, 999),
                  child: const SizedBox(height: 3, child: ColoredBox(color: AppColors.negative)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

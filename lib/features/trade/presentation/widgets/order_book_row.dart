import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../trade_theme.dart';
import '../../../market/domain/market.dart';
import '../../application/providers.dart';

class OrderBookRow extends ConsumerWidget {
  const OrderBookRow({
    super.key,
    required this.level,
    required this.buy,
    required this.maximum,
    this.precision = const MarketPrecision(),
    this.compact = false,
    this.reversed = false,
  });
  final bool compact;
  final bool reversed;
  final BookLevel level;
  final bool buy;
  final double maximum;
  final MarketPrecision precision;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: () => ref.read(orderPriceProvider.notifier).setPrice(marketInput(level.price)),
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedFractionallySizedBox(
              alignment: compact && !reversed ? Alignment.centerRight : Alignment.centerLeft,
              widthFactor: maximum <= 0 ? 0 : (level.quantity / maximum).clamp(0, 1),
              heightFactor: 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: ColoredBox(
                key: const Key('order-book-quantity-bar'),
                color: compact
                    ? (buy ? TradeColors.positive : TradeColors.negative).withValues(alpha: .15)
                    : buy
                    ? AppColors.positiveBookDepth
                    : AppColors.negativeBookDepth,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10, vertical: compact ? 3 : 4.5),
          child: Row(
            textDirection: reversed ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: reversed ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    marketNumber(level.price, minimumDecimals: precision.priceDecimals),
                    style: TextStyle(
                      fontSize: compact ? 11 : 10,
                      color: compact
                          ? (buy ? TradeColors.accent : TradeColors.negative)
                          : (buy ? AppColors.positive : AppColors.negative),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: reversed ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(
                    marketNumber(level.quantity, minimumDecimals: precision.quantityDecimals),
                    style: TextStyle(
                      fontSize: compact ? 11 : 10,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

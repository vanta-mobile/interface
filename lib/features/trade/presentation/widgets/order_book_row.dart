import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../trade_theme.dart';
import '../../../market/domain/market.dart';
import '../../../market/domain/market.dart' as format show compact;
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
    this.cumulative,
    this.quoteSize = false,
  });
  final bool compact;

  /// Compact book only: cumulative depth share drawn behind the level bar.
  final double? cumulative;

  /// Shows the level's quote notional instead of its base quantity.
  final bool quoteSize;
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
        if (cumulative case final share?)
          _DepthBar(
            barKey: const Key('order-book-cumulative-bar'),
            share: share,
            alignment: Alignment.centerRight,
            color: (buy ? TradeColors.positive : TradeColors.negative).withValues(alpha: .07),
          ),
        _DepthBar(
          barKey: const Key('order-book-quantity-bar'),
          share: maximum <= 0 ? 0 : level.quantity / maximum,
          alignment: compact && !reversed ? Alignment.centerRight : Alignment.centerLeft,
          color: compact
              ? (buy ? TradeColors.positive : TradeColors.negative).withValues(alpha: .15)
              : buy
              ? AppColors.positiveBookDepth
              : AppColors.negativeBookDepth,
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 10,
            vertical: compact ? 3.5 : 4.5,
          ),
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
                      height: compact ? 16 / 11 : null,
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
                    quoteSize
                        ? format.compact(level.quantity * level.price)
                        : marketNumber(level.quantity, minimumDecimals: precision.quantityDecimals),
                    style: TextStyle(
                      fontSize: 10,
                      height: compact ? 16 / 10 : null,
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

/// Depth background that grows from zero when its row slot appears and eases
/// to each new share, matching the reference book's 300 ms scale transition.
class _DepthBar extends StatelessWidget {
  const _DepthBar({
    required this.barKey,
    required this.share,
    required this.alignment,
    required this.color,
  });
  final Key barKey;
  final double share;
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final target = share.isFinite ? share.clamp(0.0, 1.0) : 0.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0 : target, end: target),
          duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOut,
          builder: (context, value, child) => FractionallySizedBox(
            alignment: alignment,
            widthFactor: value,
            heightFactor: 1,
            child: child,
          ),
          child: ColoredBox(key: barKey, color: color),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/providers.dart';
import '../../../market/domain/market.dart';
import '../../../market/application/market_providers.dart';
import 'chart_touch_scroll.dart';

class DepthCanvas extends ConsumerWidget {
  const DepthCanvas({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider).value;
    List<DepthEntity> cumulative(List<BookLevel> levels, bool bids) {
      var amount = 0.0;
      final result = <DepthEntity>[];
      for (final level in levels) {
        amount += level.quantity;
        result.add(DepthEntity(level.price, amount));
      }
      return bids ? result.reversed.toList() : result;
    }

    if (book == null || book.bids.isEmpty || book.asks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            tr(context, book?.connected == false ? 'bookError' : 'bookWaiting'),
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ChartTouchScroll(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: DepthChart(
          cumulative(book.bids, true),
          cumulative(book.asks, false),
          const DepthChartColors(
            upColor: AppColors.positive,
            dnColor: AppColors.negative,
            upFillPathColor: AppColors.positiveDepth,
            dnFillPathColor: AppColors.negativeDepth,
            defaultTextColor: AppColors.muted,
            annotationColor: AppColors.text,
            selectFillColor: AppColors.raised,
            selectBorderColor: AppColors.line,
            crossColor: AppColors.secondary,
            barrierColor: AppColors.line,
          ),
          chartTranslations: DepthChartTranslations(
            price: tr(context, 'price'),
            amount: tr(context, 'quantity'),
          ),
          baseUnit: marketDrawingDecimals(
            [...book.bids, ...book.asks].map((l) => l.quantity),
            minimum: ref.watch(selectedPrecisionProvider).quantityDecimals,
          ),
          quoteUnit: marketDrawingDecimals(
            [...book.bids, ...book.asks].map((l) => l.price),
            minimum: ref.watch(selectedPrecisionProvider).priceDecimals,
          ),
        ),
      ),
    );
  }
}

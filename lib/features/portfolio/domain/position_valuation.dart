import 'package:decimal/decimal.dart';

import '../../market/domain/mark_prices.dart';
import 'position_risk.dart';

class PositionValuation {
  PositionValuation({required PositionRisk position, required MarkPriceQuote? quote})
    : mark = quote?.price ?? position.markPrice,
      usesPublicMark = quote != null,
      notional =
          quote == null ||
              position.balanceOnly ||
              position.units == null ||
              position.units!.margin != position.units!.quote
          ? null
          : position.quantity * quote.price,
      unrealizedProfit =
          quote == null ||
              position.balanceOnly ||
              position.entryPrice <= Decimal.zero ||
              position.units == null ||
              position.units!.margin != position.units!.quote
          ? null
          : position.quantity * (quote.price - position.entryPrice);

  final Decimal? mark;
  final bool usesPublicMark;
  final Decimal? notional, unrealizedProfit;
}

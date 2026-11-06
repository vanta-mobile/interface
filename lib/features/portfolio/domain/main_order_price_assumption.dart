import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'live_order.dart';

/// Reference prices for opening margin and immediate opening loss. These do
/// not constrain a market fill, convert a quote input, or predict liquidation.
class MainOrderPriceAssumption {
  const MainOrderPriceAssumption({required this.margin, required this.loss});
  final Decimal margin, loss;

  /// Matches the public futuresCalculatePre price branches with exact decimal
  /// arithmetic. Its TWO_WAY constant is used by that function in both account
  /// modes; it is not a user-selected slippage limit or an exchange guarantee.
  factory MainOrderPriceAssumption.resolve(LiveOrderContext context, LiveOrderDraft draft) {
    if (!draft.validPegShape || !draft.validTrailingShape || !draft.validEntireShape) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    if (draft.attachment?.entryPeg != null) {
      // Deeper compound pegs require their own depth quote, never level one.
      throw const AccountReadFailure('liveCapacityPriceUnavailable');
    }
    final mark = context.markPrice, bid = context.bid, ask = context.ask;
    if (mark <= Decimal.zero ||
        bid != null && bid <= Decimal.zero ||
        ask != null && ask <= Decimal.zero ||
        bid != null && ask != null && bid > ask) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    if (draft.market) {
      final Decimal execution;
      if (draft.buy) {
        final precision = context.rules.pricePrecision;
        if (precision == null) throw const AccountReadFailure('liveCapacityPriceUnavailable');
        if (precision < 0 || precision > 80) {
          throw const AccountReadFailure('accountDataInvalid');
        }
        execution = ((ask ?? mark) * Decimal.parse('1.0005')).floor(scale: precision);
      } else {
        execution = bid ?? mark;
      }
      if (execution <= Decimal.zero) {
        throw const AccountReadFailure('liveCapacityPriceUnavailable');
      }
      return MainOrderPriceAssumption(margin: execution, loss: execution);
    }
    final entered = draft.peg == null
        ? parseOrderDecimal(draft.price)
        : context.referenceExecutionPrice(draft);
    if (entered == null || entered <= Decimal.zero) {
      throw AccountReadFailure(
        draft.peg == null ? 'liveOrderInvalidPrice' : 'liveCapacityPriceUnavailable',
      );
    }
    var execution = entered;
    if (!draft.buy) {
      if (mark > execution) execution = mark;
      if (bid != null && bid > execution) execution = bid;
    }
    return MainOrderPriceAssumption(margin: execution, loss: entered);
  }
}

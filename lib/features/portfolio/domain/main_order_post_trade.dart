import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'futures_position_mode.dart';
import 'live_order.dart';
import 'live_order_opening_cost.dart';
import 'main_order_capacity.dart';
import 'main_order_price_assumption.dart';
import 'position_margin_mode.dart';

/// One hypothetical fully filled entry. Entry value and allocated collateral
/// remain rational through reductions/reversals; no intermediate display rounding.
class MainOrderPostTrade {
  const MainOrderPostTrade({
    required this.original,
    required this.quantity,
    required this.entryValue,
    required this.isolatedWallet,
    required this.crossWalletChange,
    required this.executionPrice,
  });
  final CapacityPosition original;
  final Decimal quantity, executionPrice;

  /// Signed quantity * weighted entry, in margin-asset units.
  final Rational entryValue, isolatedWallet, crossWalletChange;
}

MainOrderPostTrade? mainOrderPostTrade({
  required MainOrderCapacitySnapshot snapshot,
  required LiveOrderContext context,
  required LiveOrderDraft draft,
  required Decimal quantity,
  required LiveOrderOpeningCost cost,
}) {
  final fee = snapshot.marketFacts?.takerFee;
  if (!context.sameAccountAnchor(snapshot.context) ||
      draft.reducing ||
      draft.entireClose ||
      draft.attachment?.entryPeg != null ||
      quantity <= Decimal.zero ||
      fee == null ||
      fee < Decimal.zero ||
      fee >= Decimal.one) {
    return null;
  }
  // Public futuresCalculatePre selects entered limits, market assumption,
  // conditional trigger or an explicitly entered trailing activation price.
  // An unspecified future trailing activation has no fixed entry assumption.
  final Decimal? execution;
  if (draft.peg != null) {
    // Hypothetical current-book fill only, not a forecast of trigger-time BBO.
    execution = context.referenceExecutionPrice(draft);
  } else if (!draft.market) {
    execution = parseOrderDecimal(draft.price);
  } else if (draft.trigger != null) {
    execution = parseOrderDecimal(draft.trigger!.price);
  } else if (draft.trailing != null) {
    execution = parseOrderDecimal(draft.trailing!.activationPrice ?? '');
  } else {
    execution = MainOrderPriceAssumption.resolve(context, draft).margin;
  }
  if (execution == null || execution <= Decimal.zero) return null;
  final side = context.mode == FuturesPositionMode.oneWay
      ? 'BOTH'
      : draft.buy
      ? 'LONG'
      : 'SHORT';
  final old = snapshot.account.positions
      .where((p) => p.symbol == context.symbol && p.side == side)
      .singleOrNull;
  if (old == null ||
      old.leverage != context.leverage ||
      old.isolated != (context.marginMode == PositionMarginMode.isolated)) {
    return null;
  }
  final before = old.quantity, beforeAbs = before.abs();
  final after = before + (draft.buy ? quantity : -quantity), afterAbs = after.abs();
  final zero = Decimal.zero.toRational();
  final opposite = before != Decimal.zero && (before > Decimal.zero) != draft.buy;
  final closed = opposite ? (quantity < beforeAbs ? quantity : beforeAbs) : Decimal.zero;
  final realized =
      closed * (execution - old.entryPrice) * Decimal.fromInt(before < Decimal.zero ? -1 : 1);
  final crossChange = (realized - quantity * execution * fee).toRational();
  final Rational entryValue;
  if (!opposite) {
    entryValue = (before * old.entryPrice + (draft.buy ? quantity : -quantity) * execution)
        .toRational();
  } else if (quantity < beforeAbs) {
    entryValue = (after * old.entryPrice).toRational();
  } else {
    entryValue = (after * execution).toRational();
  }
  var wallet = old.isolatedWallet.toRational();
  if (!opposite) {
    wallet += cost.total;
  } else if (quantity < beforeAbs) {
    final released = wallet * (closed / beforeAbs);
    final uncovered = released + realized.toRational();
    wallet = wallet * (afterAbs / beforeAbs) + (uncovered < zero ? uncovered : zero);
  } else if (after == Decimal.zero) {
    wallet = zero;
  } else {
    // Fully release the old leg before allocating the newly opened remainder.
    // Do not reuse the incremental margin of the old, opposite position.
    final uncovered = wallet + realized.toRational();
    wallet =
        (afterAbs * execution / Decimal.fromInt(old.leverage)) +
        cost.openingLoss.toRational() +
        (uncovered < zero ? uncovered : zero);
  }
  return MainOrderPostTrade(
    original: old,
    quantity: after,
    entryValue: entryValue,
    isolatedWallet: wallet,
    crossWalletChange: crossChange,
    executionPrice: execution,
  );
}

import 'package:decimal/decimal.dart';

import 'live_order.dart';
import 'live_order_peg.dart';
import 'live_order_trigger.dart';

/// Partial orders reduce a chosen quantity; entire orders close whatever the
/// position holds when they trigger (`closePosition`, market execution only).
enum PositionTpSlScope { partial, entire }

/// One take-profit or stop-loss leg as entered on the Set TP/SL page. Without
/// a limit price or BBO peg the leg executes at market when triggered.
class PositionTpSlLeg {
  const PositionTpSlLeg({
    required this.kind,
    required this.trigger,
    required this.basis,
    this.limitPrice,
    this.peg,
  });
  final LiveOrderTriggerKind kind;
  final String trigger;
  final LiveOrderTriggerBasis basis;
  final String? limitPrice;
  final LiveOrderPeg? peg;

  /// The closing order for [side]. [quantity] is ignored for entire closes.
  LiveOrderDraft draft({
    required String side,
    required bool long,
    required PositionTpSlScope scope,
    required String quantity,
  }) {
    final entire = scope == PositionTpSlScope.entire;
    final limit = !entire && (peg != null || limitPrice != null);
    return LiveOrderDraft(
      buy: !long,
      market: !limit,
      quantity: entire ? '' : quantity,
      price: limit && peg == null ? limitPrice! : '',
      closingSide: side,
      trigger: LiveOrderTrigger(kind: kind, price: trigger, basis: basis),
      entireClose: entire,
      peg: limit ? peg : null,
    );
  }
}

/// Estimated PnL if [quantity] closes exactly at [trigger]; excludes fees,
/// funding and slippage.
Decimal? estimatedTriggerPnl({
  required Decimal entry,
  required bool long,
  required Decimal? quantity,
  required Decimal? trigger,
}) {
  if (quantity == null || trigger == null || entry <= Decimal.zero) return null;
  return quantity.abs() * (trigger - entry) * Decimal.fromInt(long ? 1 : -1);
}

/// Estimated return on initial margin at [trigger], in percent to 2 places.
Decimal? estimatedTriggerRoi({
  required Decimal entry,
  required bool long,
  required int leverage,
  required Decimal? trigger,
}) {
  if (trigger == null || entry <= Decimal.zero || leverage <= 0) return null;
  final delta = (trigger - entry) * Decimal.fromInt(long ? 1 : -1);
  final hundredths = (delta * Decimal.fromInt(leverage * 10000) / entry).round();
  return Decimal.fromBigInt(hundredths) * Decimal.parse('0.01');
}

/// Base quantity for a quote [amount] valued at [price], floored to the
/// conditional-order step. Null unless both are positive.
Decimal? closeQuantityForQuote(LiveOrderContext data, Decimal? amount, Decimal? price) {
  if (amount == null || price == null || amount <= Decimal.zero || price <= Decimal.zero) {
    return null;
  }
  final raw = (amount / price).toDecimal(scaleOnInfinitePrecision: 24);
  final quantity = data.rules.limitQuantity.floor(raw);
  return quantity > Decimal.zero ? quantity : null;
}

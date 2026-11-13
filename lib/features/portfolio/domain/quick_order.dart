import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'aster_open_orders.dart';
import 'futures_position_mode.dart';
import 'live_order.dart';
import 'position_leverage.dart';

class QuickOrderSizing {
  QuickOrderSizing({
    required this.context,
    required this.takerFee,
    required Iterable<LeverageBracket> brackets,
    required this.orders,
  }) : brackets = List.unmodifiable(brackets);
  final LiveOrderContext context;
  final Decimal takerFee;
  final List<LeverageBracket> brackets;
  final AsterOpenOrders orders;

  /// A reference budget, not the exchange's maximum executable quantity.
  /// Reserve entry fees, existing position exposure and same-direction orders.
  /// Do not budget released margin, rebates, other-asset collateral or fills.
  Decimal? quantity(bool buy, int percent) {
    final data = context, price = buy ? context.ask : context.bid;
    final available = data.funds?.account.availableBalance;
    if (![25, 50, 75, 100].contains(percent) ||
        price == null ||
        price <= Decimal.zero ||
        available == null ||
        available <= Decimal.zero ||
        data.leverage <= 0 ||
        takerFee < Decimal.zero ||
        orders.address.toLowerCase() != data.address.toLowerCase()) {
      return null;
    }
    final caps = brackets.where((b) => b.maximum >= data.leverage).map((b) => b.cap);
    if (caps.isEmpty) return null;
    final cap = caps.reduce((a, b) => a > b ? a : b);
    final positionSide = data.mode == FuturesPositionMode.oneWay
        ? 'BOTH'
        : buy
        ? 'LONG'
        : 'SHORT';
    final direction = Decimal.fromInt(buy ? 1 : -1);
    final held = data.mode == FuturesPositionMode.oneWay
        ? (data.positions['BOTH']?.quantity ?? Decimal.zero) * direction
        : data.positions.values.fold(Decimal.zero, (n, p) => n + p.quantity.abs());
    final sameDirection = orders.orders.where(
      (o) =>
          o.symbol == data.symbol &&
          o.positionSide == positionSide &&
          o.side == (buy ? 'BUY' : 'SELL'),
    );
    var pending = sameDirection
        .where((o) => !o.reduceOnly && !o.closePosition)
        .fold(Decimal.zero, (n, o) => n + o.remainingQty);
    // Pending reductions may consume the existing opposite position before
    // this new order arrives. Do not spend that closing capacity twice.
    if (data.mode == FuturesPositionMode.oneWay && held < Decimal.zero) {
      final reduction = sameDirection.any((o) => o.closePosition)
          ? -held
          : sameDirection
                .where((o) => o.reduceOnly)
                .fold(Decimal.zero, (n, o) => n + o.remainingQty);
      pending += reduction < -held ? reduction : -held;
    }
    final headroom = cap - (held + pending) * data.markPrice;
    if (headroom <= Decimal.zero) return Decimal.zero;
    final leverage = Decimal.fromInt(data.leverage);
    final feeRate = takerFee > Decimal.zero ? takerFee : Decimal.zero;
    final budget = (available * leverage) / (price * (Decimal.one + feeRate * leverage));
    final risk = headroom / (price > data.markPrice ? price : data.markPrice);
    final rule = data.rules.marketQuantity;
    var maximum = budget < risk ? budget : risk;
    if (maximum > rule.maximum.toRational()) maximum = rule.maximum.toRational();
    final raw = maximum * Decimal.fromInt(percent).toRational() / Decimal.fromInt(100).toRational();
    if (raw < rule.minimum.toRational()) return Decimal.zero;
    final steps = ((raw - rule.minimum.toRational()) / rule.step.toRational()).floor();
    return rule.minimum + Decimal.fromBigInt(steps) * rule.step;
  }
}

/// Base quantity for a typed quote [amount]: the amount divided by the best ask
/// (buy) or bid (sell), floored to the market quantity step. Null when the
/// amount is not a positive decimal or the quote is unavailable; zero when the
/// amount is below one minimum step.
Decimal? quickOrderQuantityFromAmount(LiveOrderContext data, bool buy, String amount) {
  final value = parseOrderDecimal(amount), price = buy ? data.ask : data.bid;
  if (value == null || value <= Decimal.zero || price == null || price <= Decimal.zero) return null;
  return data.rules.marketQuantity.floor((value / price).toDecimal(scaleOnInfinitePrecision: 24));
}

/// Reference pre-check for a quick market entry: the initial margin of the part
/// that opens exposure (fees excluded) exceeds the available balance. Unknown
/// prices or balances never block; the exchange remains authoritative.
bool quickOrderExceedsBalance(LiveOrderContext data, bool buy, String quantity) {
  final amount = parseOrderDecimal(quantity), price = buy ? data.ask : data.bid;
  final available = data.funds?.account.availableBalance;
  if (amount == null || price == null || available == null || data.leverage <= 0) return false;
  var opening = amount;
  // One-way entries first consume an opposite position, which needs no margin.
  if (data.mode == FuturesPositionMode.oneWay) {
    final held = data.positions['BOTH']?.quantity ?? Decimal.zero;
    if (buy ? held < Decimal.zero : held > Decimal.zero) opening -= held.abs();
  }
  if (opening <= Decimal.zero) return false;
  return opening * price > available * Decimal.fromInt(data.leverage);
}

abstract interface class QuickOrderRepository {
  Future<QuickOrderSizing> readSizing({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
}

class QuickOrderState {
  /// [quantity] holds the typed quote-asset amount; the base quantity is
  /// derived at the current ask/bid when an order is prepared.
  const QuickOrderState({
    this.quantity = '',
    this.percent,
    this.sizing,
    this.loading = false,
    this.failure,
  });
  final String quantity;
  final int? percent;
  final QuickOrderSizing? sizing;
  final bool loading;
  final AccountReadFailure? failure;
}

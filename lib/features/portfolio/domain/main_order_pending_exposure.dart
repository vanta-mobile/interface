import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'account_snapshot.dart';
import 'aster_open_orders.dart';
import 'futures_position_mode.dart';
import 'live_order.dart';
import 'live_order_peg.dart';
import 'live_order_opening_cost.dart';
import 'main_order_capacity.dart';

LiveOrderOpeningExposure mainOrderPendingExposure({
  required LiveOrderContext context,
  required List<CapacityPosition> positions,
  required AsterOpenOrders orders,
}) {
  if (orders.address.toLowerCase() != context.address.toLowerCase()) {
    throw const AccountReadFailure('authWalletChanged');
  }
  return capacitySymbolExposure(
    symbol: context.symbol,
    mode: context.mode,
    markPrice: context.markPrice,
    positions: positions,
    orders: orders.orders,
    corroborate: true,
  );
}

/// Reuse the same opening/closing and pending-notional rules for every symbol
/// which shares a margin budget. Revalued margins must not be corroborated
/// against the older signed mark's rounded openOrderInitialMargin.
LiveOrderOpeningExposure capacitySymbolExposure({
  required String symbol,
  required FuturesPositionMode mode,
  required Decimal markPrice,
  required List<CapacityPosition> positions,
  required Iterable<AsterOpenOrder> orders,
  bool corroborate = false,
}) {
  final hedge = mode == FuturesPositionMode.hedge;
  final sides = hedge ? {'LONG', 'SHORT'} : {'BOTH'};
  if (positions.length != sides.length ||
      positions.map((p) => p.side).toSet().length != sides.length ||
      positions.any((p) => p.symbol != symbol || !sides.contains(p.side)) ||
      positions.any(
        (p) => p.leverage != positions.first.leverage || p.isolated != positions.first.isolated,
      )) {
    throw const AccountReadFailure('accountDataInvalid');
  }
  final leverage = positions.first.leverage;
  var bids = Decimal.zero, asks = Decimal.zero;
  for (final o in orders) {
    if (o.symbol != symbol ||
        !(hedge ? {'LONG', 'SHORT'} : {'BOTH'}).contains(o.positionSide) ||
        !{'BUY', 'SELL'}.contains(o.side) ||
        o.remainingQty < Decimal.zero) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final closing =
        o.reduceOnly ||
        o.closePosition ||
        hedge && (o.positionSide == 'LONG' ? o.side == 'SELL' : o.side == 'BUY');
    if (closing || o.remainingQty == Decimal.zero) continue;
    // Ordinary LIMIT pegs resolve once at placement. A signed positive resolved
    // price is a fixed pending limit; unknown/deeper pegs and untriggered orders
    // cannot be inferred from a current quote or rounded aggregate margin.
    final knownPeg =
        o.pegPriceType == null || LiveOrderPeg.values.any((p) => p.wire == o.pegPriceType);
    if (o.type != 'LIMIT' || !knownPeg || o.price <= Decimal.zero) {
      throw const AccountReadFailure('liveCapacityPendingUnknown');
    }
    if (o.side == 'BUY') {
      bids += o.remainingQty * o.price;
    } else {
      asks += o.remainingQty * o.price;
    }
  }
  final exposure = hedge
      ? LiveOrderOpeningExposure.hedge(
          markPrice: markPrice,
          leverage: leverage,
          grossNotional: positions.fold(Decimal.zero, (n, p) => n + p.notional.abs()) + bids + asks,
        )
      : LiveOrderOpeningExposure.oneWay(
          markPrice: markPrice,
          leverage: leverage,
          positionQuantity: positions.single.quantity,
          positionNotional: positions.single.notional,
          buyOrderNotional: bids,
          sellOrderNotional: asks,
        );
  if (!corroborate) return exposure;
  if (hedge) {
    for (final p in positions) {
      final pending = p.side == 'LONG' ? bids : asks;
      _corroborate(pending / Decimal.fromInt(leverage), p.orderMargin);
    }
  } else {
    final extra = exposure.currentNotional - positions.single.notional.abs();
    _corroborate(extra / Decimal.fromInt(leverage), positions.single.orderMargin);
  }
  return exposure;
}

void _corroborate(Rational expected, Decimal reported) {
  // Account margin examples use eight decimal places. Respect greater supplied
  // precision and allow at most one last-place reporting quantum. This only
  // corroborates independently known limit-order notionals; it never derives
  // unknown notionals from rounded aggregate margin.
  final scale = reported.scale > 8 ? reported.scale : 8;
  final quantum = Decimal.parse('1e-$scale').toRational();
  if ((expected - reported.toRational()).abs() > quantum) {
    throw const AccountReadFailure('liveCapacityChanged');
  }
}

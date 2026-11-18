import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'aster_open_orders.dart';
import 'futures_position_mode.dart';
import 'live_order.dart';
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
  );
}

/// Reuse the same opening/closing and pending-notional rules for every symbol
/// which shares a margin budget. Pending reservations come from the open
/// orders themselves; the exchange's openOrderInitialMargin uses its own mark
/// and formula, so it never matches exactly and is not a consistency check.
LiveOrderOpeningExposure capacitySymbolExposure({
  required String symbol,
  required FuturesPositionMode mode,
  required Decimal markPrice,
  required List<CapacityPosition> positions,
  required Iterable<AsterOpenOrder> orders,
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
    // Untriggered conditional and trailing orders reserve no margin until they
    // trigger; a triggered one is reported as LIMIT or MARKET.
    if (_untriggered.contains(o.type)) continue;
    // A fixed or resolved limit reserves at its price. A BBO limit reports
    // price 0, and Aster values open-order margin at the current mark, so an
    // unresolved price uses the mark rather than blocking every estimate.
    final price = o.type == 'LIMIT' && o.price > Decimal.zero ? o.price : markPrice;
    if (o.side == 'BUY') {
      bids += o.remainingQty * price;
    } else {
      asks += o.remainingQty * price;
    }
  }
  return hedge
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
}

const _untriggered = {
  'STOP',
  'STOP_MARKET',
  'TAKE_PROFIT',
  'TAKE_PROFIT_MARKET',
  'TRAILING_STOP_MARKET',
};

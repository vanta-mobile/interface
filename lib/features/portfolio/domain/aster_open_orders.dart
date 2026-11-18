import 'package:decimal/decimal.dart';

import 'aster_account.dart';

class AsterOpenOrders implements WalletAccountSnapshot {
  AsterOpenOrders({
    required this.address,
    required this.receivedAt,
    required Iterable<AsterOpenOrder> orders,
    Map<String, AsterContractUnits> units = const {},
    this.lastEventAt,
  }) : orders = List.unmodifiable(orders),
       units = Map.unmodifiable(units);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<AsterOpenOrder> orders;
  final Map<String, AsterContractUnits> units;
  final DateTime? lastEventAt;
}

class AsterOpenOrder {
  const AsterOpenOrder({
    required this.symbol,
    required this.orderId,
    required this.side,
    required this.positionSide,
    required this.type,
    required this.status,
    required this.time,
    required this.origQty,
    required this.executedQty,
    required this.price,
    this.stopPrice,
    this.activatePrice,
    this.priceRate,
    this.workingType,
    this.pegPriceType,
    this.reduceOnly = false,
    this.closePosition = false,
    this.timeInForce,
    this.units,
    this.updatedAt,
    this.originalType,
    this.transactionHash,
    this.clientOrderId,
    this.strategy,
  });
  final String symbol, orderId, side, positionSide, type, status;
  final String? originalType;

  /// Aster Chain transaction of the placement. Liquidation and non-L1 orders
  /// have none, so explorer links stay unavailable for them.
  final String? transactionHash;
  final String? clientOrderId;

  /// OTO/OTOCO membership when the exchange row reports it (undocumented on
  /// REST; asterdex.com rows carry it). Null when the row has no linkage.
  final OpenOrderStrategy? strategy;

  /// User-stream T is an update time, never a substitute for REST time.
  final DateTime? time;
  final DateTime? updatedAt;
  final Decimal origQty, executedQty, price;
  final Decimal? stopPrice, activatePrice, priceRate;
  final String? workingType, pegPriceType;
  final String? timeInForce;
  final AsterContractUnits? units;
  final bool reduceOnly, closePosition;
  Decimal get remainingQty => origQty - executedQty;
  Decimal? get limitNotional =>
      type == 'LIMIT' && pegPriceType == null && price > Decimal.zero && origQty > Decimal.zero
      ? origQty * price
      : null;
}

/// Strategy linkage and TP/SL exit prices of an OTO/OTOCO order. Leg 1 is the
/// entry; legs 2/3 are its reduce-only take-profit / stop-loss exits.
class OpenOrderStrategy {
  const OpenOrderStrategy({
    required this.strategyId,
    this.type,
    this.sequence,
    this.takeProfit,
    this.stopLoss,
    this.legs = const [],
  });
  final String strategyId;
  final String? type;
  final int? sequence;
  final Decimal? takeProfit, stopLoss;

  /// All legs read with `strategyOpenOrder`, by sequence; empty when the
  /// linkage came from the open-order row alone.
  final List<OpenOrderStrategyLeg> legs;
  bool get entry => sequence == null || sequence == 1;
  bool get hasExits => takeProfit != null || stopLoss != null;
}

/// One leg of an OTO/OTOCO strategy: 1 is the entry, 2/3 its exits.
class OpenOrderStrategyLeg {
  const OpenOrderStrategyLeg({
    required this.sequence,
    required this.type,
    required this.status,
    required this.buy,
    required this.quantity,
    this.stopPrice,
    this.reduceOnly = false,
  });
  final int sequence;

  /// Exchange order type and status, e.g. `TAKE_PROFIT_MARKET` / `NEW`.
  final String type, status;
  final bool buy, reduceOnly;
  final Decimal quantity;
  final Decimal? stopPrice;
}

int compareOpenOrders(AsterOpenOrder a, AsterOpenOrder b) {
  final aTime = a.time ?? a.updatedAt;
  final bTime = b.time ?? b.updatedAt;
  final timeOrder = aTime == null || bTime == null ? 0 : bTime.compareTo(aTime);
  if (timeOrder != 0) return timeOrder;
  final symbolOrder = a.symbol.compareTo(b.symbol);
  return symbolOrder != 0 ? symbolOrder : a.orderId.compareTo(b.orderId);
}

typedef OpenOrdersReadState = AccountSnapshotState<AsterOpenOrders>;
typedef AsterOpenOrdersRepository = WalletAccountRepository<AsterOpenOrders>;

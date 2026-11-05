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
  });
  final String symbol, orderId, side, positionSide, type, status;
  final String? originalType;

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

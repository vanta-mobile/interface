import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'spot_history.dart';

/// Spot orders have base/quote quantities, without futures position metadata.
class SpotOpenOrder {
  const SpotOpenOrder({
    required this.symbol,
    required this.orderId,
    required this.clientOrderId,
    required this.side,
    required this.type,
    required this.status,
    required this.quantity,
    required this.executed,
    required this.price,
    required this.quoteFilled,
    this.time,
    this.updatedAt,
    this.timeInForce,
    this.originalType,
    this.averagePrice,
    this.stopPrice,
    this.quoteOrderQuantity,
    this.units,
  });
  final String symbol, orderId, clientOrderId, side, type, status;
  final String? timeInForce, originalType;
  final DateTime? time, updatedAt;
  final Decimal quantity, executed, price, quoteFilled;
  final Decimal? averagePrice, stopPrice, quoteOrderQuantity;
  final SpotSymbolUnits? units;
  String get key => '$symbol:$orderId';
  bool get terminal =>
      const {'FILLED', 'CANCELED', 'REJECTED', 'EXPIRED', 'EXPIRED_IN_MATCH'}.contains(status);
  Decimal? get remaining => quantity > Decimal.zero ? quantity - executed : null;

  SpotOpenOrder withContext({SpotOpenOrder? previous, SpotSymbolUnits? symbolUnits}) =>
      SpotOpenOrder(
        symbol: symbol,
        orderId: orderId,
        clientOrderId: clientOrderId,
        side: side,
        type: type,
        status: status,
        quantity: quantity,
        executed: executed,
        price: price,
        quoteFilled: quoteFilled,
        time: time ?? previous?.time,
        updatedAt: updatedAt,
        timeInForce: timeInForce ?? previous?.timeInForce,
        originalType: originalType ?? previous?.originalType,
        averagePrice: averagePrice,
        stopPrice: stopPrice ?? previous?.stopPrice,
        quoteOrderQuantity: quoteOrderQuantity ?? previous?.quoteOrderQuantity,
        units: symbolUnits ?? previous?.units ?? units,
      );
}

class SpotOpenOrders implements WalletAccountSnapshot {
  SpotOpenOrders({
    required this.address,
    required this.receivedAt,
    required Iterable<SpotOpenOrder> orders,
    Map<String, SpotSymbolUnits> units = const {},
    this.lastEventAt,
  }) : orders = List.unmodifiable(orders),
       units = Map.unmodifiable(units);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<SpotOpenOrder> orders;
  final Map<String, SpotSymbolUnits> units;
  final DateTime? lastEventAt;
  bool get unitsUnavailable => orders.any((o) => o.units == null);
}

class SpotOpenOrderUpdate {
  const SpotOpenOrderUpdate({required this.order, required this.eventTime});
  final SpotOpenOrder order;
  final DateTime eventTime;
}

int compareSpotOpenOrders(SpotOpenOrder a, SpotOpenOrder b) {
  final aTime = a.time ?? a.updatedAt, bTime = b.time ?? b.updatedAt;
  if (aTime == null && bTime != null) return 1;
  if (aTime != null && bTime == null) return -1;
  final t = aTime == null ? 0 : bTime!.compareTo(aTime);
  if (t != 0) return t;
  final s = a.symbol.compareTo(b.symbol);
  return s != 0 ? s : a.orderId.compareTo(b.orderId);
}

typedef SpotOpenOrdersState = AccountSnapshotState<SpotOpenOrders>;
typedef SpotOpenOrdersRepository = WalletAccountRepository<SpotOpenOrders>;

import 'package:decimal/decimal.dart';

import 'aster_account.dart';
import 'aster_open_orders.dart';

/// Validated private event. An event describes one order, not the full list.
class OpenOrderUpdate {
  const OpenOrderUpdate({
    required this.symbol,
    required this.orderId,
    required this.status,
    required this.eventTime,
    required this.transactionTime,
    required this.side,
    required this.positionSide,
    required this.type,
    required this.origQty,
    required this.executedQty,
    required this.price,
    required this.reduceOnly,
    required this.timeInForce,
    this.closePosition,
    this.stopPrice,
    this.activatePrice,
    this.priceRate,
    this.workingType,
    this.pegPriceType,
    this.originalType,
  });
  final String symbol, orderId, status, side, positionSide, type, timeInForce;
  final DateTime eventTime, transactionTime;
  final Decimal origQty, executedQty, price;
  final Decimal? stopPrice, activatePrice, priceRate;
  final bool reduceOnly;
  final bool? closePosition;
  final String? workingType, pegPriceType;
  final String? originalType;
  String get key => '$symbol:$orderId';
  bool get terminal => const {'FILLED', 'CANCELED', 'EXPIRED', 'REJECTED'}.contains(status);

  AsterOpenOrder toOrder({AsterOpenOrder? previous, AsterContractUnits? units}) => AsterOpenOrder(
    symbol: symbol,
    orderId: orderId,
    status: status,
    side: side,
    positionSide: positionSide,
    type: type,
    originalType: originalType ?? previous?.originalType,
    // Missing creation time remains unknown, even for execution type NEW.
    time: previous?.time,
    updatedAt: transactionTime,
    origQty: origQty,
    executedQty: executedQty,
    price: price,
    reduceOnly: reduceOnly,
    closePosition: closePosition ?? previous?.closePosition ?? false,
    timeInForce: timeInForce,
    stopPrice: stopPrice ?? previous?.stopPrice,
    activatePrice: activatePrice ?? previous?.activatePrice,
    priceRate: priceRate ?? previous?.priceRate,
    workingType: workingType ?? previous?.workingType,
    pegPriceType: pegPriceType ?? previous?.pegPriceType,
    units: units ?? previous?.units,
  );
}

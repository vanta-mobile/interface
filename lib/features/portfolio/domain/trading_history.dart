import 'package:decimal/decimal.dart';

enum TradingHistoryTab { orders, positions, trades, transactions }

sealed class TradingHistoryRecord {
  const TradingHistoryRecord({required this.symbol, required this.time});
  final String symbol;
  final DateTime time;
  String get key;
}

class HistoryOrder extends TradingHistoryRecord {
  const HistoryOrder({
    required super.symbol,
    required super.time,
    required this.id,
    required this.side,
    required this.positionSide,
    required this.type,
    required this.status,
    required this.executed,
    this.quantity,
    this.price,
    this.averagePrice,
    this.reduceOnly,
    this.closePosition,
    this.updatedAt,
    this.quoteFilled,
    this.stopPrice,
    this.activationPrice,
    this.callbackRate,
    this.workingType,
  });
  final String id, side, type, status;
  final String? positionSide;
  final Decimal executed;
  final Decimal? quantity, price, averagePrice;
  final bool? reduceOnly, closePosition;
  final DateTime? updatedAt;
  final Decimal? quoteFilled, stopPrice, activationPrice, callbackRate;
  final String? workingType;
  @override
  String get key => 'order:$symbol:$id';
  Decimal? get filledValue =>
      quoteFilled ?? (averagePrice == null ? null : executed * averagePrice!);
  Decimal? get orderValue =>
      quantity == null || price == null || price! <= Decimal.zero ? null : quantity! * price!;
}

class HistoryFill extends TradingHistoryRecord {
  const HistoryFill({
    required super.symbol,
    required super.time,
    required this.id,
    required this.side,
    required this.price,
    required this.quantity,
    required this.fee,
    this.orderId,
    this.positionSide,
    this.notional,
    this.feeAsset,
    this.realizedPnl,
    this.maker,
  });
  final String id, side;
  final String? orderId, positionSide, feeAsset;
  final Decimal price, quantity, fee;
  final Decimal? notional, realizedPnl;
  final bool? maker;
  // active_buy is aggressor direction, not maker/taker liquidity role.
  @override
  String get key => 'fill:$symbol:$id';
}

class HistoryPosition extends TradingHistoryRecord {
  const HistoryPosition({
    required super.symbol,
    required super.time,
    required this.id,
    required this.side,
    required this.entryPrice,
    required this.maxQuantity,
    required this.realizedPnl,
    required this.fees,
    required this.status,
    required this.inferred,
    required this.liquidated,
    this.closedAt,
    this.exitPrice,
  });
  final String id, side, status;
  final DateTime? closedAt;
  final Decimal entryPrice, maxQuantity, realizedPnl, fees;
  final Decimal? exitPrice;
  final bool inferred, liquidated;
  @override
  String get key => 'position:$id';
}

class HistoryTransaction extends TradingHistoryRecord {
  const HistoryTransaction({
    required super.symbol,
    required super.time,
    required this.id,
    required this.type,
    required this.asset,
    required this.amount,
  });
  final String id, type, asset;
  final Decimal amount;
  @override
  String get key => 'transaction:$id';
}

class TradingHistoryCursor {
  const TradingHistoryCursor(this.main, [this.transfers]);
  final String? main, transfers;
}

class TradingHistoryPage {
  TradingHistoryPage({
    required this.address,
    required Iterable<TradingHistoryRecord> records,
    this.next,
    this.partial = false,
    this.recentDays,
  }) : records = List.unmodifiable(records);
  final String address;
  final List<TradingHistoryRecord> records;
  final TradingHistoryCursor? next;
  final bool partial;
  final int? recentDays;
}

abstract interface class TradingOrderFillsRepository {
  Future<TradingHistoryPage> readOrderFills(
    HistoryOrder order, {
    required String address,
    TradingHistoryCursor? cursor,
  });
}

bool historyUsesAster(TradingHistoryTab tab) =>
    tab == TradingHistoryTab.orders || tab == TradingHistoryTab.transactions;

abstract interface class TradingHistoryRepository {
  Future<TradingHistoryPage> read(
    TradingHistoryTab tab, {
    required String address,
    TradingHistoryCursor? cursor,
  });
}

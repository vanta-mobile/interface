import 'package:decimal/decimal.dart';

import 'aster_account.dart';
import 'history_window.dart';
export 'history_window.dart';

enum FuturesHistoryKind { orders, trades, income }

class FuturesHistoryQuery {
  const FuturesHistoryQuery({
    required this.kind,
    required this.window,
    this.symbol = '',
    this.incomeType = '',
  });
  final FuturesHistoryKind kind;
  final HistoryWindow window;
  final String symbol, incomeType;
  bool get valid => window.valid && validSymbol && validIncomeType;
  bool get validSymbol =>
      (symbol.isEmpty && kind != FuturesHistoryKind.trades) ||
      RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol);
  bool get validIncomeType =>
      incomeType.isEmpty ||
      kind == FuturesHistoryKind.income && futuresIncomeTypes.contains(incomeType);
  FuturesHistoryQuery inWindow(HistoryWindow value) =>
      FuturesHistoryQuery(kind: kind, window: value, symbol: symbol, incomeType: incomeType);
  @override
  bool operator ==(Object other) =>
      other is FuturesHistoryQuery &&
      kind == other.kind &&
      window == other.window &&
      symbol == other.symbol &&
      incomeType == other.incomeType;
  @override
  int get hashCode => Object.hash(kind, window, symbol, incomeType);
}

const futuresIncomeTypes = [
  'TRANSFER',
  'WITHDRAW',
  'DEPOSIT',
  'WELCOME_BONUS',
  'REALIZED_PNL',
  'FUNDING_FEE',
  'COMMISSION',
  'INSURANCE_CLEAR',
  'MARKET_MERCHANT_RETURN_REWARD',
  'REFERRAL_KICKBACK',
  'COMMISSION_REBATE',
  'MARKET_MAKER_REBATE',
  'API_REBATE',
  'CONTEST_REWARD',
  'CROSS_COLLATERAL_TRANSFER',
  'INTERNAL_TRANSFER',
  'AUTO_EXCHANGE',
];

sealed class FuturesHistoryRecord {
  const FuturesHistoryRecord({required this.symbol, required this.time});
  final String symbol;
  final DateTime time;
  String get key;
  DateTime get versionTime => time;
}

class FuturesOrderRecord extends FuturesHistoryRecord {
  const FuturesOrderRecord({
    required super.symbol,
    required super.time,
    required this.orderId,
    required this.side,
    required this.positionSide,
    required this.type,
    required this.status,
    required this.updatedAt,
    required this.quantity,
    required this.executed,
    required this.price,
    this.originalType,
    this.clientOrderId,
    this.quoteFilled,
    this.averagePrice,
    this.stopPrice,
    this.timeInForce,
    this.workingType,
    this.activationPrice,
    this.callbackRate,
    this.reduceOnly,
    this.closePosition,
    this.priceProtect,
    this.units,
  });
  final String orderId, side, positionSide, type, status;
  final String? originalType, clientOrderId, timeInForce, workingType;
  final DateTime updatedAt;
  final Decimal quantity, executed, price;
  final Decimal? quoteFilled, averagePrice, stopPrice, activationPrice, callbackRate;
  final bool? reduceOnly, closePosition, priceProtect;
  final AsterContractUnits? units;
  @override
  String get key => '$symbol:$orderId';
  @override
  DateTime get versionTime => updatedAt;
}

class FuturesTradeRecord extends FuturesHistoryRecord {
  const FuturesTradeRecord({
    required super.symbol,
    required super.time,
    required this.tradeId,
    required this.orderId,
    required this.side,
    required this.positionSide,
    required this.price,
    required this.quantity,
    required this.quoteQuantity,
    required this.commission,
    required this.commissionAsset,
    required this.realizedPnl,
    required this.maker,
    this.units,
  });
  final String tradeId, orderId, side, positionSide, commissionAsset;
  final Decimal price, quantity, quoteQuantity, commission, realizedPnl;
  final bool maker;
  final AsterContractUnits? units;
  @override
  String get key => '$symbol:$tradeId';
}

class FuturesIncomeRecord extends FuturesHistoryRecord {
  const FuturesIncomeRecord({
    required super.symbol,
    required super.time,
    required this.transactionId,
    required this.asset,
    required this.type,
    required this.income,
    this.tradeId,
  });
  final String transactionId, asset, type;
  final String? tradeId;
  final Decimal income;
  // Official tranId uniqueness is scoped to incomeType, not globally.
  @override
  String get key => '$type:$transactionId';
}

class FuturesHistorySnapshot implements WalletAccountSnapshot {
  FuturesHistorySnapshot({
    required this.address,
    required this.query,
    required this.receivedAt,
    required Iterable<FuturesHistoryRecord> records,
  }) : records = List.unmodifiable(records);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final FuturesHistoryQuery query;
  final List<FuturesHistoryRecord> records;
  bool get unitsUnavailable => records.any(
    (r) => switch (r) {
      FuturesOrderRecord() => r.units == null,
      FuturesTradeRecord() => r.units == null,
      _ => false,
    },
  );
}

class FuturesHistoryPage extends FuturesHistorySnapshot {
  FuturesHistoryPage({
    required super.address,
    required super.query,
    required super.receivedAt,
    required super.records,
    required this.rawCount,
  });
  static const limit = 1000;
  final int rawCount;
}

class FuturesHistoryState extends AccountSnapshotState<FuturesHistorySnapshot> {
  FuturesHistoryState({
    required this.query,
    super.account,
    super.step,
    super.failure,
    super.stale,
    Iterable<HistoryWindow> pending = const [],
    this.truncated = false,
  }) : pending = List.unmodifiable(pending);
  final FuturesHistoryQuery query;
  final List<HistoryWindow> pending;
  final bool truncated;
}

abstract interface class FuturesHistoryRepository {
  Future<FuturesHistoryPage> read({
    required String address,
    required FuturesHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
}

bool futuresHistoryMatches(FuturesHistoryRecord r, FuturesHistoryQuery query) =>
    r.time.millisecondsSinceEpoch >= query.window.start &&
    r.time.millisecondsSinceEpoch <= query.window.end &&
    (query.symbol.isEmpty || r.symbol == query.symbol) &&
    switch ((query.kind, r)) {
      (FuturesHistoryKind.orders, FuturesOrderRecord()) => true,
      (FuturesHistoryKind.trades, FuturesTradeRecord()) => true,
      (FuturesHistoryKind.income, FuturesIncomeRecord(:final type)) =>
        query.incomeType.isEmpty || type == query.incomeType,
      _ => false,
    };

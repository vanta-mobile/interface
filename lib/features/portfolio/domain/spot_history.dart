import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'history_window.dart';
export 'history_window.dart';

enum SpotHistoryKind { orders, trades, transactions }

class SpotHistoryQuery {
  const SpotHistoryQuery({required this.kind, required this.window, this.scope = ''});
  final SpotHistoryKind kind;
  final HistoryWindow window;

  /// Exact Spot symbol for orders/trades, or exact asset for transactions.
  final String scope;
  bool get validWindow => kind == SpotHistoryKind.orders ? window.fitsRequest : window.valid;
  bool get validScope =>
      scope.isEmpty || RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(scope);
  SpotHistoryQuery inWindow(HistoryWindow value) =>
      SpotHistoryQuery(kind: kind, scope: scope, window: value);
  @override
  bool operator ==(Object other) =>
      other is SpotHistoryQuery &&
      kind == other.kind &&
      scope == other.scope &&
      window == other.window;
  @override
  int get hashCode => Object.hash(kind, scope, window);
}

class SpotSymbolUnits {
  const SpotSymbolUnits({required this.base, required this.quote});
  final String base, quote;
}

sealed class SpotHistoryRecord {
  const SpotHistoryRecord({required this.symbol, required this.time});
  final String symbol;
  final DateTime time;
  String get key;
  DateTime get versionTime => time;
}

class SpotOrderRecord extends SpotHistoryRecord {
  const SpotOrderRecord({
    required super.symbol,
    required super.time,
    required this.orderId,
    required this.side,
    required this.type,
    required this.status,
    required this.updatedAt,
    required this.quantity,
    required this.executed,
    required this.price,
    required this.quoteFilled,
    this.averagePrice,
    this.stopPrice,
    this.timeInForce,
    this.units,
  });
  final String orderId, side, type, status;
  final String? timeInForce;
  final DateTime updatedAt;
  final Decimal quantity, executed, price, quoteFilled;
  final Decimal? averagePrice, stopPrice;
  final SpotSymbolUnits? units;
  @override
  String get key => '$symbol:$orderId';
  @override
  DateTime get versionTime => updatedAt;
}

class SpotTradeRecord extends SpotHistoryRecord {
  const SpotTradeRecord({
    required super.symbol,
    required super.time,
    required this.tradeId,
    required this.orderId,
    required this.side,
    required this.price,
    required this.quantity,
    required this.quoteQuantity,
    required this.commission,
    required this.commissionAsset,
    required this.maker,
    this.units,
  });
  final String tradeId, orderId, side, commissionAsset;
  final Decimal price, quantity, quoteQuantity, commission;
  final bool maker;
  final SpotSymbolUnits? units;
  @override
  String get key => '$symbol:$tradeId';
}

class SpotTransactionRecord extends SpotHistoryRecord {
  const SpotTransactionRecord({
    required super.symbol,
    required super.time,
    required this.transactionId,
    required this.asset,
    required this.type,
    required this.delta,
    this.tradeId,
  });
  final String transactionId, asset, type;
  final String? tradeId;
  final Decimal delta;
  @override
  String get key => '$type:$asset:$transactionId';
}

class SpotHistorySnapshot implements WalletAccountSnapshot {
  SpotHistorySnapshot({
    required this.address,
    required this.query,
    required this.receivedAt,
    required Iterable<SpotHistoryRecord> records,
  }) : records = List.unmodifiable(records);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final SpotHistoryQuery query;
  final List<SpotHistoryRecord> records;
  bool get unitsUnavailable => records.any(
    (r) => switch (r) {
      SpotOrderRecord() => r.units == null,
      SpotTradeRecord() => r.units == null,
      _ => false,
    },
  );
}

class SpotHistoryPage extends SpotHistorySnapshot {
  SpotHistoryPage({
    required super.address,
    required super.query,
    required super.receivedAt,
    required super.records,
    required this.rawCount,
  });
  static const limit = 1000;
  final int rawCount;
}

class SpotHistoryState extends AccountSnapshotState<SpotHistorySnapshot> {
  SpotHistoryState({
    required this.query,
    super.account,
    super.step,
    super.failure,
    super.stale,
    Iterable<HistoryWindow> pending = const [],
    this.truncated = false,
  }) : pending = List.unmodifiable(pending);
  final SpotHistoryQuery query;
  final List<HistoryWindow> pending;
  final bool truncated;
}

abstract interface class SpotHistoryRepository {
  Future<SpotHistoryPage> read({
    required String address,
    required SpotHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  });
}

List<SpotHistoryRecord> sortSpotHistory(Iterable<SpotHistoryRecord> records) =>
    records.toList()..sort((a, b) {
      final compared = b.time.compareTo(a.time);
      return compared == 0 ? a.key.compareTo(b.key) : compared;
    });

/// Executions and ledger entries are immutable events. Conflicting duplicates
/// cannot be resolved by arrival order without hiding a financial difference.
bool historyRecordsConflict(SpotHistoryRecord previous, SpotHistoryRecord next) {
  if (previous.time != next.time) return true;
  return switch ((previous, next)) {
    (SpotOrderRecord(), SpotOrderRecord()) => false,
    (SpotTradeRecord a, SpotTradeRecord b) =>
      (
            a.symbol,
            a.orderId,
            a.side,
            a.price,
            a.quantity,
            a.quoteQuantity,
            a.commission,
            a.commissionAsset,
            a.maker,
          ) !=
          (
            b.symbol,
            b.orderId,
            b.side,
            b.price,
            b.quantity,
            b.quoteQuantity,
            b.commission,
            b.commissionAsset,
            b.maker,
          ),
    (SpotTransactionRecord a, SpotTransactionRecord b) =>
      (a.symbol, a.asset, a.type, a.delta, a.tradeId) !=
          (b.symbol, b.asset, b.type, b.delta, b.tradeId),
    _ => true,
  };
}

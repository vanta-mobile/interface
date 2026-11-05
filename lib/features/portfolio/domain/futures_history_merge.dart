import 'futures_history.dart';

/// Ignore metadata enrichment when comparing financial records. Conflicting
/// immutable fills/ledger entries and same-version orders must not be hidden.
bool futuresHistoryConflict(FuturesHistoryRecord previous, FuturesHistoryRecord next) {
  if (previous.key != next.key || previous.symbol != next.symbol || previous.time != next.time) {
    return true;
  }
  return switch ((previous, next)) {
    (FuturesOrderRecord a, FuturesOrderRecord b) => _orderConflict(a, b),
    (FuturesTradeRecord a, FuturesTradeRecord b) =>
      (
            a.orderId,
            a.side,
            a.positionSide,
            a.price,
            a.quantity,
            a.quoteQuantity,
            a.commission,
            a.commissionAsset,
            a.realizedPnl,
            a.maker,
          ) !=
          (
            b.orderId,
            b.side,
            b.positionSide,
            b.price,
            b.quantity,
            b.quoteQuantity,
            b.commission,
            b.commissionAsset,
            b.realizedPnl,
            b.maker,
          ),
    (FuturesIncomeRecord a, FuturesIncomeRecord b) =>
      (a.asset, a.type, a.income, a.tradeId) != (b.asset, b.type, b.income, b.tradeId),
    _ => true,
  };
}

bool _orderConflict(FuturesOrderRecord a, FuturesOrderRecord b) {
  if ((a.side, a.positionSide, a.clientOrderId) != (b.side, b.positionSide, b.clientOrderId)) {
    return true;
  }
  if (a.originalType != null && b.originalType != null && a.originalType != b.originalType) {
    return true;
  }
  if (a.updatedAt == b.updatedAt) {
    return (
          a.type,
          a.originalType,
          a.status,
          a.quantity,
          a.executed,
          a.price,
          a.quoteFilled,
          a.averagePrice,
          a.stopPrice,
          a.timeInForce,
          a.workingType,
          a.activationPrice,
          a.callbackRate,
          a.reduceOnly,
          a.closePosition,
          a.priceProtect,
        ) !=
        (
          b.type,
          b.originalType,
          b.status,
          b.quantity,
          b.executed,
          b.price,
          b.quoteFilled,
          b.averagePrice,
          b.stopPrice,
          b.timeInForce,
          b.workingType,
          b.activationPrice,
          b.callbackRate,
          b.reduceOnly,
          b.closePosition,
          b.priceProtect,
        );
  }
  final old = a.updatedAt.isBefore(b.updatedAt) ? a : b;
  final next = identical(old, a) ? b : a;
  const terminal = {'FILLED', 'CANCELED', 'REJECTED', 'EXPIRED', 'EXPIRED_IN_MATCH'};
  return next.executed < old.executed ||
      (old.quoteFilled != null &&
          next.quoteFilled != null &&
          next.quoteFilled! < old.quoteFilled!) ||
      terminal.contains(old.status) && next.status != old.status;
}

List<FuturesHistoryRecord> mergeFuturesHistory(
  Iterable<FuturesHistoryRecord> previous,
  Iterable<FuturesHistoryRecord> next,
) {
  final records = <String, FuturesHistoryRecord>{for (final r in previous) r.key: r};
  for (final r in next) {
    final old = records[r.key];
    if (old != null && futuresHistoryConflict(old, r)) {
      throw const FormatException('Conflicting history');
    }
    if (old == null || !r.versionTime.isBefore(old.versionTime)) records[r.key] = r;
  }
  return records.values.toList()..sort((a, b) {
    final result = b.time.compareTo(a.time);
    return result == 0 ? a.key.compareTo(b.key) : result;
  });
}

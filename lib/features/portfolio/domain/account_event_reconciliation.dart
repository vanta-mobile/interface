import 'package:decimal/decimal.dart';

import 'account_update_book.dart';
import 'aster_account.dart';
import 'position_risk.dart';

AsterAccount reconcileAccountUpdates(
  AsterAccount snapshot,
  AccountUpdateBook book, {
  required int since,
}) {
  final assets = {for (final row in snapshot.assets) row.asset: row};
  final positions = {for (final row in snapshot.positions) '${row.symbol}:${row.side}': row};
  final assetClocks = {...snapshot.assetUpdatedAt};
  final positionClocks = {...snapshot.positionUpdatedAt};
  final assetEvents = {...snapshot.assetEventAt}, positionEvents = {...snapshot.positionEventAt};
  var latest = snapshot.lastEventAt;
  var changed = false;
  for (final patch in book.balances(
    assetClocks,
    since: since,
    eventClocks: assetEvents,
    existingKeys: assets.keys.toSet(),
  )) {
    final row = patch.value;
    assets[row.asset] = AsterAssetBalance(
      asset: row.asset,
      walletBalance: row.walletBalance,
      crossWalletBalance: row.crossWalletBalance,
      eventTime: patch.eventTime,
    );
    assetClocks[row.asset] = patch.transactionTime;
    assetEvents[row.asset] = patch.eventTime;
    latest = _latest(latest, patch.eventTime);
    changed = true;
  }
  for (final patch in book.positions(
    positionClocks,
    since: since,
    eventClocks: positionEvents,
    existingKeys: positions.keys.toSet(),
  )) {
    final row = patch.value;
    final previous = positions[row.key];
    if (row.quantity == Decimal.zero && (!row.isolated || row.isolatedWallet >= Decimal.zero)) {
      positions.remove(row.key);
    } else {
      positions[row.key] = AsterPosition(
        symbol: row.symbol,
        side: row.side,
        quantity: row.quantity,
        entryPrice: row.entryPrice,
        unrealizedProfit: row.unrealizedProfit,
        isolated: row.isolated,
        isolatedWallet: row.isolatedWallet,
        units: snapshot.units[row.symbol] ?? previous?.units,
        eventTime: patch.eventTime,
      );
    }
    positionClocks[row.key] = patch.transactionTime;
    positionEvents[row.key] = patch.eventTime;
    latest = _latest(latest, patch.eventTime);
    changed = true;
  }
  if (!changed) return snapshot;
  _validateModes(positions.values.map((p) => (p.symbol, p.side, p.quantity)));
  return AsterAccount(
    address: snapshot.address,
    receivedAt: snapshot.receivedAt,
    assets: assets.values,
    positions: positions.values,
    // Events cannot reconstruct portfolio totals, margin, or available funds.
    canTrade: snapshot.canTrade,
    units: snapshot.units,
    assetUpdatedAt: assetClocks,
    positionUpdatedAt: positionClocks,
    assetEventAt: assetEvents,
    positionEventAt: positionEvents,
    lastEventAt: latest,
  );
}

PositionRiskSnapshot reconcileRiskUpdates(
  PositionRiskSnapshot snapshot,
  AccountUpdateBook book, {
  required int since,
}) {
  final positions = {for (final row in snapshot.positions) '${row.symbol}:${row.side}': row};
  final clocks = {...snapshot.positionUpdatedAt};
  final eventClocks = {...snapshot.positionEventAt};
  var latest = snapshot.lastEventAt;
  var changed = false;
  for (final patch in book.positions(
    clocks,
    since: since,
    eventClocks: eventClocks,
    existingKeys: positions.keys.toSet(),
  )) {
    final row = patch.value;
    final previous = positions[row.key];
    if (row.quantity == Decimal.zero && (!row.isolated || row.isolatedWallet >= Decimal.zero)) {
      positions.remove(row.key);
    } else {
      positions[row.key] = PositionRisk(
        symbol: row.symbol,
        side: row.side,
        quantity: row.quantity,
        entryPrice: row.entryPrice,
        isolated: row.isolated,
        isolatedWallet: row.isolatedWallet,
        unrealizedProfit: row.unrealizedProfit,
        // The event has no leverage, mark, notional, liquidation or margin.
        // Never attach the former position's risk numbers to a new quantity.
        markPrice: null,
        leverage: null,
        updatedAt: patch.transactionTime,
        eventTime: patch.eventTime,
        units: snapshot.units[row.symbol] ?? previous?.units,
      );
    }
    clocks[row.key] = patch.transactionTime;
    eventClocks[row.key] = patch.eventTime;
    latest = _latest(latest, patch.eventTime);
    changed = true;
  }
  if (!changed) return snapshot;
  _validateModes(positions.values.map((p) => (p.symbol, p.side, p.quantity)));
  return PositionRiskSnapshot(
    address: snapshot.address,
    receivedAt: snapshot.receivedAt,
    positions: positions.values,
    positionUpdatedAt: clocks,
    positionEventAt: eventClocks,
    units: snapshot.units,
    lastEventAt: latest,
  );
}

DateTime _latest(DateTime? current, DateTime next) =>
    current == null || next.isAfter(current) ? next : current;

void _validateModes(Iterable<(String, String, Decimal)> rows) {
  final modes = <String, Set<String>>{};
  for (final (symbol, side, quantity) in rows) {
    if (quantity == Decimal.zero) continue;
    final sides = modes.putIfAbsent(symbol, () => {})..add(side);
    if (sides.contains('BOTH') && sides.length > 1) throw const FormatException();
  }
}

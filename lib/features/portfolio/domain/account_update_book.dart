import 'account_update.dart';

class AccountEventsFull implements Exception {
  const AccountEventsFull();
}

/// A bounded, per-wallet ledger. Unlike order IDs, position keys can reopen:
/// zero records protect against older events, not against newer positions.
class AccountUpdateBook {
  AccountUpdateBook({this.capacity = 10000});
  final int capacity;
  int revision = 0;
  final _balances = <String, AccountPatch<AccountBalanceUpdate>>{};
  final _positions = <String, AccountPatch<AccountPositionUpdate>>{};

  bool add(AccountUpdate update) {
    final next = revision + 1;
    final balances = <String, AccountPatch<AccountBalanceUpdate>>{};
    final positions = <String, AccountPatch<AccountPositionUpdate>>{};
    for (final row in update.balances) {
      final old = _balances[row.asset];
      if (_accept(old, update, old?.value.sameValues(row) ?? false)) {
        balances[row.asset] = AccountPatch(next, update.eventTime, update.transactionTime, row);
      }
    }
    for (final row in update.positions) {
      final old = _positions[row.key];
      if (_accept(old, update, old?.value.sameValues(row) ?? false)) {
        positions[row.key] = AccountPatch(next, update.eventTime, update.transactionTime, row);
      }
    }
    if ({..._balances.keys, ...balances.keys}.length +
            {..._positions.keys, ...positions.keys}.length >
        capacity) {
      throw const AccountEventsFull();
    }
    // Commit atomically: ambiguity or capacity failure cannot apply half an event.
    revision = next;
    _balances.addAll(balances);
    _positions.addAll(positions);
    return balances.isNotEmpty || positions.isNotEmpty;
  }

  bool _accept<T>(AccountPatch<T>? old, AccountUpdate update, bool same) {
    if (old == null) return true;
    if (update.eventTime.isBefore(old.eventTime) ||
        update.transactionTime.isBefore(old.transactionTime)) {
      return false;
    }
    if (update.eventTime == old.eventTime && update.transactionTime == old.transactionTime) {
      // Millisecond timestamps cannot order conflicting payloads. Recheck REST
      // instead of choosing an arbitrary financial value.
      if (!same) throw const FormatException();
      return false;
    }
    return true;
  }

  Iterable<AccountPatch<AccountBalanceUpdate>> balances(
    Map<String, DateTime> clocks, {
    required int since,
    Map<String, DateTime> eventClocks = const {},
    Set<String> existingKeys = const {},
  }) => _balances.entries
      .where(
        (e) =>
            e.value.applies(clocks[e.key], eventClocks[e.key], since, existingKeys.contains(e.key)),
      )
      .map((e) => e.value);
  Iterable<AccountPatch<AccountPositionUpdate>> positions(
    Map<String, DateTime> clocks, {
    required int since,
    Map<String, DateTime> eventClocks = const {},
    Set<String> existingKeys = const {},
  }) => _positions.entries
      .where(
        (e) =>
            e.value.applies(clocks[e.key], eventClocks[e.key], since, existingKeys.contains(e.key)),
      )
      .map((e) => e.value);
}

class AccountPatch<T> {
  const AccountPatch(this.revision, this.eventTime, this.transactionTime, this.value);
  final int revision;
  final DateTime eventTime, transactionTime;
  final T value;
  bool applies(DateTime? serverUpdatedAt, DateTime? appliedEventAt, int since, bool existing) =>
      serverUpdatedAt == null
      ? revision > since || existing
      : transactionTime.isAfter(serverUpdatedAt) ||
            transactionTime == serverUpdatedAt &&
                appliedEventAt != null &&
                eventTime.isAfter(appliedEventAt);
}

import 'spot_open_orders.dart';

/// A full Spot baseline is required. Partial events cannot establish an empty
/// account; terminal tombstones prevent delayed reports reopening old orders.
class SpotOpenOrdersEventBook {
  SpotOpenOrdersEventBook({this.capacity = 10000});
  final int capacity;
  final _events = <String, (int, SpotOpenOrderUpdate)>{};
  int revision = 0;
  bool add(SpotOpenOrderUpdate update) {
    revision++;
    final next = update.order, previous = _events[next.key]?.$2;
    if (next.updatedAt == null) throw const FormatException();
    if (previous != null) {
      final old = previous.order;
      if (old.terminal ||
          update.eventTime.isBefore(previous.eventTime) ||
          next.updatedAt!.isBefore(old.updatedAt!) ||
          next.executed < old.executed) {
        return false;
      }
      if (update.eventTime == previous.eventTime &&
          next.updatedAt == old.updatedAt &&
          next.executed == old.executed &&
          !next.terminal) {
        return false;
      }
    } else if (_events.length >= capacity) {
      throw const FormatException();
    }
    _events[next.key] = (revision, update);
    return true;
  }

  SpotOpenOrders reconcile(SpotOpenOrders snapshot, {required int since}) {
    final orders = {for (final o in snapshot.orders) o.key: o};
    var changed = false;
    var eventAt = snapshot.lastEventAt;
    for (final (revision, event) in _events.values) {
      final next = event.order, previous = orders[next.key];
      if (next.terminal) {
        if (orders.remove(next.key) != null) {
          changed = true;
          if (eventAt == null || event.eventTime.isAfter(eventAt)) eventAt = event.eventTime;
        }
        continue;
      }
      if (previous == null && revision <= since) continue;
      final previousTime = previous?.updatedAt;
      if (previousTime != null &&
          (next.updatedAt!.isBefore(previousTime) ||
              next.updatedAt == previousTime && next.executed <= previous!.executed)) {
        continue;
      }
      if (previous != null && next.executed < previous.executed) continue;
      orders[next.key] = next.withContext(
        previous: previous,
        symbolUnits: snapshot.units[next.symbol],
      );
      changed = true;
      if (eventAt == null || event.eventTime.isAfter(eventAt)) eventAt = event.eventTime;
    }
    if (!changed) return snapshot;
    return SpotOpenOrders(
      address: snapshot.address,
      receivedAt: snapshot.receivedAt,
      orders: orders.values.toList()..sort(compareSpotOpenOrders),
      units: snapshot.units,
      lastEventAt: eventAt,
    );
  }
}

import 'aster_open_orders.dart';
import 'open_order_update.dart';

/// Orders are keyed by symbol + ID. A complete REST baseline is mandatory;
/// events cannot prove an empty list or the absence of missed orders.
class OpenOrdersEventBook {
  OpenOrdersEventBook({this.capacity = 10000});
  final int capacity;
  final _events = <String, (int, OpenOrderUpdate)>{};
  final _closed = <String>{};
  int revision = 0;
  bool hasEventAfter(String symbol, String id, int since) =>
      (_events['$symbol:$id']?.$1 ?? 0) > since;
  bool hasSymbolEventAfter(String symbol, int since) =>
      _events.values.any((entry) => entry.$1 > since && entry.$2.symbol == symbol);

  bool add(OpenOrderUpdate update) {
    revision++;
    final previous = _events[update.key]?.$2;
    if (_closed.contains(update.key) || previous?.terminal == true && !update.terminal) {
      return false;
    }
    if (previous != null) {
      final eventOrder = update.eventTime.compareTo(previous.eventTime);
      if (eventOrder < 0 ||
          update.transactionTime.isBefore(previous.transactionTime) ||
          update.executedQty < previous.executedQty) {
        return false;
      }
      if (eventOrder == 0 &&
          update.transactionTime == previous.transactionTime &&
          update.executedQty == previous.executedQty &&
          (previous.terminal || !update.terminal)) {
        return false;
      }
    } else if (_events.length + _closed.length >= capacity) {
      throw const FormatException();
    }
    _events[update.key] = (revision, update);
    return true;
  }

  /// A verified GET found an order terminal/absent. Never revive it with a
  /// delayed NEW event, including after the stream reconnects.
  void closeVerified(String symbol, String id) {
    final key = '$symbol:$id';
    if (_closed.contains(key)) return;
    if (!_events.containsKey(key) && _closed.length + _events.length >= capacity) {
      throw const FormatException();
    }
    _events.remove(key);
    _closed.add(key);
  }

  AsterOpenOrders reconcile(AsterOpenOrders snapshot, {required int since}) {
    final orders = {for (final o in snapshot.orders) '${o.symbol}:${o.orderId}': o};
    var changed = false;
    var lastEventAt = snapshot.lastEventAt;
    void applied(OpenOrderUpdate event) {
      if (lastEventAt == null || event.eventTime.isAfter(lastEventAt!)) {
        lastEventAt = event.eventTime;
      }
    }

    for (final key in _closed) {
      changed = orders.remove(key) != null || changed;
    }
    for (final entry in _events.entries) {
      final (revision, event) = entry.value;
      final previous = orders[entry.key];
      if (event.terminal) {
        if (orders.remove(entry.key) != null) {
          changed = true;
          applied(event);
        }
        continue;
      }
      if (previous == null && revision <= since) continue;
      final updatedAt = previous?.updatedAt ?? previous?.time;
      // REST updateTime and o.T both describe the order update. E orders
      // stream events; never compare it with a local receive clock.
      if (updatedAt != null &&
          (event.transactionTime.isBefore(updatedAt) ||
              event.transactionTime == updatedAt &&
                  previous != null &&
                  event.executedQty <= previous.executedQty)) {
        continue;
      }
      if (previous != null && event.executedQty < previous.executedQty) continue;
      orders[entry.key] = event.toOrder(previous: previous, units: snapshot.units[event.symbol]);
      applied(event);
      changed = true;
    }
    if (!changed) return snapshot;
    final sorted = orders.values.toList()..sort(compareOpenOrders);
    return AsterOpenOrders(
      address: snapshot.address,
      receivedAt: snapshot.receivedAt,
      orders: sorted,
      units: snapshot.units,
      lastEventAt: lastEventAt,
    );
  }
}

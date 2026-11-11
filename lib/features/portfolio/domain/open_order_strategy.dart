import 'aster_open_orders.dart';

/// How to look up the OTO/OTOCO strategy behind an open order with the
/// documented `strategyOpenOrder` read, which needs an ID and a strategy type.
class OpenOrderStrategyQuery {
  const OpenOrderStrategyQuery({required this.parameters, required this.types});
  final Map<String, String> parameters;

  /// Candidate strategy types, tried in order; the next is tried only when
  /// the exchange reports the strategy as not found (-2013).
  final List<String> types;
}

/// Orders placed by this app use `<clientStrategyId>-<leg>` client order IDs
/// (see attached_order.dart). Orders placed elsewhere are only queryable when
/// the exchange row itself reports its strategy.
final _appLeg = RegExp(r'^(vanta-[0-9a-z]+-[0-9a-z]+)-([123])$');

OpenOrderStrategyQuery? openOrderStrategyQuery(AsterOpenOrder order) {
  if (order.closePosition) return null;
  final known = order.strategy;
  if (known != null) {
    // OTO has a single exit, so a row that already names it is complete.
    final complete =
        !known.entry ||
        known.type == 'OTO' && known.hasExits ||
        known.takeProfit != null && known.stopLoss != null;
    if (complete) return null;
    return OpenOrderStrategyQuery(
      parameters: {'strategyId': known.strategyId},
      types: known.type == null ? const ['OTOCO', 'OTO'] : [known.type!],
    );
  }
  final match = _appLeg.firstMatch(order.clientOrderId ?? '');
  if (match == null) return null;
  return OpenOrderStrategyQuery(
    parameters: {'clientStrategyId': match.group(1)!},
    types: const ['OTOCO', 'OTO'],
  );
}

abstract interface class OpenOrderStrategyRepository {
  /// Null when no open strategy matches the order.
  Future<OpenOrderStrategy?> read({
    required String address,
    required AsterOpenOrder order,
    required OpenOrderStrategyQuery query,
    required bool Function() isCurrent,
  });
}

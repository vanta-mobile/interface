import 'aster_open_orders.dart';
import 'position_risk.dart';

const _takeProfitTypes = {'TAKE_PROFIT', 'TAKE_PROFIT_MARKET'};
const _stopLossTypes = {'STOP', 'STOP_MARKET'};
const _openStatuses = {'NEW', 'PARTIALLY_FILLED'};

bool isTakeProfitExit(AsterOpenOrder order) => _takeProfitTypes.contains(order.type);

/// An open take-profit / stop-loss order that closes [position]. Aster has no
/// position linkage, so this matches symbol, side and closing direction.
bool isPositionExit(PositionRisk position, AsterOpenOrder order) =>
    _openStatuses.contains(order.status) &&
    order.symbol == position.symbol &&
    order.positionSide == position.side &&
    order.side == (position.long ? 'SELL' : 'BUY') &&
    (_takeProfitTypes.contains(order.type) || _stopLossTypes.contains(order.type)) &&
    // One-way rows close only when marked; hedge rows close their side.
    (position.side != 'BOTH' || order.reduceOnly || order.closePosition);

/// TP/SL placed together by this app share a client-ID base: Set TP/SL legs
/// end in `-tp`/`-sl`, OTO/OTOCO exit legs in `-2`/`-3`.
final _pairedLeg = RegExp(r'^(vanta-[0-9a-z]+-[0-9a-z]+)-(tp|sl|2|3)$');

/// Client order ID of one Set TP/SL leg, paired by [base].
String positionExitClientId(String base, {required bool takeProfit}) =>
    '$base-${takeProfit ? 'tp' : 'sl'}';

/// One take-profit and/or stop-loss of a position, set together.
class PositionExitGroup {
  const PositionExitGroup({this.takeProfit, this.stopLoss})
    : assert(takeProfit != null || stopLoss != null);
  final AsterOpenOrder? takeProfit, stopLoss;
  List<AsterOpenOrder> get orders => [?takeProfit, ?stopLoss];

  /// Entire groups close the whole position (`closePosition`).
  bool get entire => (takeProfit ?? stopLoss)!.closePosition;
}

/// [position]'s TP/SL grouped by strategy or paired client ID, earliest first.
/// Orders without a known pairing form their own group.
List<PositionExitGroup> positionExitGroups(PositionRisk position, Iterable<AsterOpenOrder> orders) {
  final exits = orders.where((o) => isPositionExit(position, o)).toList()
    ..sort((a, b) => compareOpenOrders(b, a));
  final slots = <String, List<AsterOpenOrder?>>{};
  for (final order in exits) {
    final slot = isTakeProfitExit(order) ? 0 : 1;
    final link =
        order.strategy?.strategyId ?? _pairedLeg.firstMatch(order.clientOrderId ?? '')?.group(1);
    var key = '${order.closePosition}:${link ?? 'order:${order.orderId}'}';
    if (slots[key]?[slot] != null) key = '${order.closePosition}:order:${order.orderId}';
    (slots[key] ??= [null, null])[slot] = order;
  }
  return [
    for (final slot in slots.values) PositionExitGroup(takeProfit: slot[0], stopLoss: slot[1]),
  ];
}

/// Groups only when the open orders belong to the position's wallet.
List<PositionExitGroup> walletPositionExitGroups(
  PositionRisk position,
  AsterOpenOrders? orders,
  String? address,
) => address != null && orders?.address.toLowerCase() == address.toLowerCase()
    ? positionExitGroups(position, orders!.orders)
    : const [];

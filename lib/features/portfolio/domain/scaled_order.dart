import 'account_snapshot.dart';
import 'live_order.dart';
import 'live_order_time_in_force.dart';
import 'scaled_order_plan.dart';
import 'scaled_order_planner.dart';

export 'scaled_order_plan.dart';
export 'scaled_order_planner.dart';

/// A change in config must stop remaining orders, not silently change the plan.
bool sameScaledConfiguration(LiveOrderContext a, LiveOrderContext b) {
  final x = a.rules, y = b.rules;
  return a.address.toLowerCase() == b.address.toLowerCase() &&
      a.symbol == b.symbol &&
      a.mode == b.mode &&
      a.leverage == b.leverage &&
      a.marginMode == b.marginMode &&
      a.funds?.assetMode == b.funds?.assetMode &&
      x.baseAsset == y.baseAsset &&
      x.quoteAsset == y.quoteAsset &&
      x.priceMinimum == y.priceMinimum &&
      x.priceMaximum == y.priceMaximum &&
      x.priceTick == y.priceTick &&
      x.limitQuantity.minimum == y.limitQuantity.minimum &&
      x.limitQuantity.maximum == y.limitQuantity.maximum &&
      x.limitQuantity.step == y.limitQuantity.step &&
      x.minimumNotional == y.minimumNotional &&
      x.percentUp == y.percentUp &&
      x.percentDown == y.percentDown &&
      y.timeInForce.contains(LiveOrderTimeInForce.gtc) &&
      y.orderTypes.contains('LIMIT');
}

class ScaledOrderIntent {
  ScaledOrderIntent({
    required this.context,
    required this.plan,
    required Iterable<String> clientIds,
    required this.revision,
    required this.epoch,
  }) : clientIds = List.unmodifiable(clientIds);
  final LiveOrderContext context;
  final ScaledOrderPlan plan;
  final List<String> clientIds;
  final int revision, epoch;
  String get address => context.address;
  bool get valid {
    if (clientIds.length != plan.orders.length ||
        clientIds.toSet().length != clientIds.length ||
        !clientIds.every((s) => RegExp(r'^[.A-Z:/a-z0-9_-]{1,36}$').hasMatch(s))) {
      return false;
    }
    try {
      final expected = planScaledOrder(context, plan.draft).orders;
      if (expected.length != plan.orders.length) return false;
      return List.generate(expected.length, (i) {
        final a = expected[i], b = plan.orders[i];
        return a.buy == b.buy &&
            a.price == b.price &&
            a.quantity == b.quantity &&
            !b.market &&
            !b.reducing &&
            !b.entireClose &&
            !b.quickEntry &&
            b.trigger == null &&
            b.trailing == null &&
            b.attachment == null &&
            b.peg == null &&
            b.timeInForce == LiveOrderTimeInForce.gtc;
      }).every((same) => same);
    } on AccountReadFailure {
      return false;
    }
  }
}

class ScaledOrderItem {
  const ScaledOrderItem({
    required this.index,
    required this.draft,
    required this.clientId,
    this.order,
    this.submitted = false,
    this.result,
    this.failure,
  });
  final int index;
  final LiveOrderDraft draft;
  final String clientId;
  final LiveOrderIntent? order;
  final bool submitted;
  final LiveOrderResult? result;
  final AccountReadFailure? failure;
  bool get needsRecheck => submitted && result?.needsRecheck != false;
}

class ScaledOrderState {
  ScaledOrderState({
    this.intent,
    Iterable<ScaledOrderItem> items = const [],
    this.step = LiveOrderStep.idle,
    this.stopRequested = false,
    this.currentIndex,
  }) : items = List.unmodifiable(items);
  final ScaledOrderIntent? intent;
  final List<ScaledOrderItem> items;
  final LiveOrderStep step;
  final bool stopRequested;
  final int? currentIndex;
  bool get busy => step != LiveOrderStep.idle;
  bool get needsRecheck => items.any((i) => i.needsRecheck);
}

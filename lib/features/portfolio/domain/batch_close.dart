import 'live_order.dart';
import 'position_risk.dart';

class BatchCloseTarget {
  const BatchCloseTarget({required this.position, required this.clientOrderId});
  final PositionRisk position;
  final String clientOrderId;
  String get key => '${position.symbol}:${position.side}';
}

class BatchCloseIntent {
  BatchCloseIntent({
    required this.snapshot,
    required Iterable<BatchCloseTarget> targets,
    required this.revision,
    required this.epoch,
    this.symbol,
  }) : targets = List.unmodifiable(targets);
  final PositionRiskSnapshot snapshot;
  final List<BatchCloseTarget> targets;
  final int revision, epoch;
  final String? symbol;
  String get address => snapshot.address;

  bool get validTargets {
    final expected = snapshot.positions
        .where((p) => !p.balanceOnly && (symbol == null || p.symbol == symbol))
        .toList();
    return expected.isNotEmpty &&
        targets.length == expected.length &&
        targets.map((t) => t.key).toSet().length == targets.length &&
        targets.map((t) => t.clientOrderId).toSet().length == targets.length &&
        targets.every(
          (t) =>
              expected.any((p) => identical(p, t.position)) &&
              RegExp(r'^[.A-Z:/a-z0-9_-]{1,36}$').hasMatch(t.clientOrderId),
        );
  }
}

class BatchCloseItem {
  const BatchCloseItem({
    required this.target,
    this.order,
    this.submitted = false,
    this.result,
    this.failure,
  });
  final BatchCloseTarget target;
  final LiveOrderIntent? order;
  final bool submitted;
  final LiveOrderResult? result;
  final AccountReadFailure? failure;
  bool get needsRecheck => submitted && result?.needsRecheck != false;
}

class BatchCloseState {
  BatchCloseState({
    this.intent,
    Map<String, BatchCloseItem> items = const {},
    this.step = LiveOrderStep.idle,
    this.currentKey,
    this.stopRequested = false,
    this.remainingAfter,
  }) : items = Map.unmodifiable(items);
  final BatchCloseIntent? intent;
  final Map<String, BatchCloseItem> items;
  final LiveOrderStep step;
  final String? currentKey;
  final bool stopRequested;
  final DateTime? remainingAfter;
  bool get busy => step != LiveOrderStep.idle;
  bool get needsRecheck => items.values.any((i) => i.needsRecheck);
}

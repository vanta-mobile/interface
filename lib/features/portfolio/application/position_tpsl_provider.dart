import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/live_order_trigger.dart';
import 'position_order_submission.dart';

export 'position_order_submission.dart' show PositionOrderOutcome;

class PositionTpSlLegResult {
  const PositionTpSlLegResult(this.kind, this.outcome, [this.failure]);
  final LiveOrderTriggerKind kind;
  final PositionOrderOutcome outcome;
  final AccountReadFailure? failure;
}

class PositionTpSlState {
  const PositionTpSlState({this.busy = false, this.results = const []});
  final bool busy;

  /// Attempted legs in submission order; legs after a non-placed one are absent.
  final List<PositionTpSlLegResult> results;
}

/// Builds one leg's order from the fresh context it will be submitted with.
typedef PositionTpSlLegBuilder = ({
  LiveOrderTriggerKind kind,
  LiveOrderDraft Function(LiveOrderContext context) draft,
});

final positionTpSlProvider =
    NotifierProvider.autoDispose<PositionTpSlController, PositionTpSlState>(
      PositionTpSlController.new,
    );

/// Places a position's take-profit and stop-loss as independent conditional
/// orders, one after another, through the live-order controller (and its
/// recovery journal). Each leg reads a fresh context first. The first leg that
/// is not verified as placed stops the sequence: a failed or unconfirmed order
/// is never resubmitted and later legs are not sent.
class PositionTpSlController extends Notifier<PositionTpSlState> {
  @override
  PositionTpSlState build() => const PositionTpSlState();

  Future<void> submit(String symbol, List<PositionTpSlLegBuilder> legs) async {
    if (state.busy || legs.isEmpty) return;
    state = const PositionTpSlState(busy: true);
    final results = <PositionTpSlLegResult>[];
    try {
      for (final leg in legs) {
        final result = await _submitLeg(symbol, leg);
        if (!ref.mounted) return;
        results.add(result);
        if (result.outcome != PositionOrderOutcome.placed) break;
      }
    } finally {
      if (ref.mounted) state = PositionTpSlState(results: List.unmodifiable(results));
    }
  }

  Future<PositionTpSlLegResult> _submitLeg(String symbol, PositionTpSlLegBuilder leg) async {
    final attempt = await submitPositionOrder(ref, symbol, leg.draft);
    return PositionTpSlLegResult(leg.kind, attempt.outcome, attempt.failure);
  }
}

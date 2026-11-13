import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import 'live_order_provider.dart';

enum PositionOrderOutcome { placed, failed, unknown }

typedef PositionOrderAttempt = ({PositionOrderOutcome outcome, AccountReadFailure? failure});

/// Submits one position order through the live-order controller (and its
/// recovery journal): reads a fresh context, builds and validates the draft on
/// it, then submits once. Placed means the signed query verified the order;
/// unknown means it was sent without a verified result and must only be
/// rechecked, never resubmitted automatically.
Future<PositionOrderAttempt> submitPositionOrder(
  Ref ref,
  String symbol,
  LiveOrderDraft Function(LiveOrderContext context) build, {
  String? clientOrderId,
}) async {
  PositionOrderAttempt failed(AccountReadFailure failure) =>
      (outcome: PositionOrderOutcome.failed, failure: failure);
  const expired = AccountReadFailure('liveOrderContextExpired');
  final live = ref.read(liveOrderProvider.notifier);
  await live.load(symbol, includeFunds: false);
  if (!ref.mounted) return failed(expired);
  final loaded = ref.read(liveOrderProvider), context = loaded.context;
  if (context == null || context.symbol != symbol || loaded.stale || loaded.busy) {
    return failed(loaded.failure ?? expired);
  }
  final draft = build(context);
  if (context.validate(draft) case final invalid?) return failed(AccountReadFailure(invalid));
  final intent = live.prepare(symbol, draft, clientOrderId: clientOrderId);
  if (intent == null) return failed(expired);
  await live.submit(intent);
  if (!ref.mounted) return (outcome: PositionOrderOutcome.unknown, failure: null);
  final after = ref.read(liveOrderProvider);
  // Without this intent in the state, the controller refused it before sending.
  if (after.intent?.clientOrderId != intent.clientOrderId) return failed(after.failure ?? expired);
  final result = after.result;
  if (result != null && result.failure == null && !result.needsRecheck) {
    return (outcome: PositionOrderOutcome.placed, failure: null);
  }
  if (after.needsRecheck) return (outcome: PositionOrderOutcome.unknown, failure: result?.failure);
  return failed(after.failure ?? result?.failure ?? expired);
}

class PositionCloseState {
  const PositionCloseState({this.busy = false, this.attempt});
  final bool busy;
  final PositionOrderAttempt? attempt;
}

final positionCloseProvider =
    NotifierProvider.autoDispose<PositionCloseController, PositionCloseState>(
      PositionCloseController.new,
    );

/// One market or limit close of a position from the Close Position sheet.
class PositionCloseController extends Notifier<PositionCloseState> {
  @override
  PositionCloseState build() => const PositionCloseState();

  Future<void> submit(String symbol, LiveOrderDraft Function(LiveOrderContext) build) async {
    if (state.busy) return;
    state = const PositionCloseState(busy: true);
    PositionOrderAttempt? attempt;
    try {
      attempt = await submitPositionOrder(ref, symbol, build);
    } finally {
      if (ref.mounted) state = PositionCloseState(attempt: attempt);
    }
  }
}

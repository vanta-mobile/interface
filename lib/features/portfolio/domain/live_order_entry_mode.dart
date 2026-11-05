import 'live_order_draft.dart';
import 'live_order_time_in_force.dart';

/// Product entry modes. Scaled owns its independent review/submit flow;
/// Chase and TWAP are not ordinary order types and cannot fall back to LIMIT.
enum LiveOrderEntryMode {
  limit,
  postOnly,
  market,
  stopLimit,
  stopMarket,
  trailing,
  chase,
  scaled,
  twap;

  bool get inline => switch (this) {
    chase || scaled || twap => false,
    _ => true,
  };
  bool get conditional => this == stopLimit || this == stopMarket;
  bool get marketExecution => this == market || this == stopMarket || this == trailing;
  LiveOrderTimeInForce get defaultPolicy =>
      this == postOnly ? LiveOrderTimeInForce.postOnly : LiveOrderTimeInForce.gtc;
}

LiveOrderEntryMode liveOrderEntryMode(LiveOrderDraft draft) => draft.trailing != null
    ? LiveOrderEntryMode.trailing
    : draft.trigger != null
    ? draft.market
          ? LiveOrderEntryMode.stopMarket
          : LiveOrderEntryMode.stopLimit
    : draft.market
    ? LiveOrderEntryMode.market
    : draft.timeInForce == LiveOrderTimeInForce.postOnly
    ? LiveOrderEntryMode.postOnly
    : LiveOrderEntryMode.limit;

import 'package:decimal/decimal.dart';

import '../../authorization/domain/builder_authorization.dart';
import 'live_order_draft.dart';
import 'live_order_time_in_force.dart';

class BuilderCommissionRates {
  const BuilderCommissionRates();

  /// A single rate applies to every possible fill of the order/strategy.
  /// Charges takerRate when any fill may be a taker, makerRate only when
  /// strictly maker-only (post-only entry with no attached exits).
  Decimal feeFor(LiveOrderDraft draft) {
    final postOnly = !draft.market && draft.timeInForce == LiveOrderTimeInForce.postOnly;
    var mayTake = !postOnly;
    if (draft.attachment case final attachment?) {
      if (attachment.exits.isNotEmpty) mayTake = true;
    }
    return mayTake ? VantaBuilder.takerRate : VantaBuilder.makerRate;
  }
}

/// Quantity/margin sizing uses the total taker cost: Aster's base rate plus
/// the fixed builder taker rate overlaid on top.
Decimal builderSizingTakerFee(Decimal base) => base + VantaBuilder.takerRate;

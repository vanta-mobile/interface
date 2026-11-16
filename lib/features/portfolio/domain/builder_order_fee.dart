import 'package:decimal/decimal.dart';

import '../../authorization/domain/builder_authorization.dart';
import 'account_snapshot.dart';
import 'live_order_draft.dart';
import 'live_order_time_in_force.dart';

class BuilderCommissionRates {
  const BuilderCommissionRates({required this.maker, required this.taker});
  final Decimal maker, taker;

  /// A single rate applies to every possible fill of the order/strategy.
  /// Never guess maker status from an ordinary limit price or the current BBO.
  Decimal feeFor(LiveOrderDraft draft) {
    final postOnly = !draft.market && draft.timeInForce == LiveOrderTimeInForce.postOnly;
    var mayMake = !draft.market && draft.timeInForce != LiveOrderTimeInForce.ioc;
    var mayTake = !postOnly;
    if (draft.attachment case final attachment?) {
      for (final exit in attachment.exits) {
        mayMake = mayMake || !exit.market;
        mayTake = true;
      }
    }
    final limits = <Decimal>[
      VantaBuilder.approvalCap,
      if (mayMake) VantaBuilder.makerTotal - maker,
      if (mayTake) VantaBuilder.takerTotal - taker,
    ];
    if (limits.any((rate) => rate < Decimal.zero)) {
      throw const AccountReadFailure('builderFeeAboveBudget');
    }
    return limits.reduce((a, b) => a < b ? a : b);
  }
}

/// Quantity/margin sizing reserves the target total taker fee. If Aster is
/// already more expensive, retain that higher cost rather than under-reserving.
Decimal builderSizingTakerFee(Decimal base) =>
    base > VantaBuilder.takerTotal ? base : VantaBuilder.takerTotal;

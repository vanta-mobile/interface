import 'account_snapshot.dart';
import 'attached_exit_input.dart';
import 'live_order.dart';
import 'live_order_attachment.dart';
import 'live_order_size.dart';
import 'main_order_capacity.dart';
import 'main_order_capacity_exceeded.dart';
import 'main_order_capacity_preview.dart';
import 'main_order_revaluation.dart';

/// Raw user choices, independent of changing conversion and valuation results.
/// These may be recalculated while reviewing, before a signature is requested.
class MainOrderReviewInput {
  const MainOrderReviewInput({
    required this.draft,
    required this.size,
    this.percent,
    this.attachment,
  });
  final LiveOrderDraft draft;
  final LiveOrderSize size;
  final int? percent;
  final AttachedOrderInput? attachment;

  ({LiveOrderDraft draft, MainOrderSidePreview side}) resolve(
    MainOrderCapacitySnapshot snapshot,
    MainOrderRevaluation valuation,
  ) {
    final preview = MainOrderCapacityPreview(
      snapshot: snapshot,
      valuation: valuation,
      draft: draft,
      unit: size.unit,
      input: size.text,
      percent: percent,
    );
    final side = draft.buy ? preview.buy : preview.sell;
    if (side.failure case final failure?) {
      if (failure.key == 'liveCapacityAboveMaximum' && side.capacity != null) {
        throw MainOrderCapacityExceeded(capacity: side.capacity!, context: valuation.context);
      }
      throw failure;
    }
    if (side.size == null) throw const AccountReadFailure('liveOrderInvalidQuantity');
    var resolved = draft.withQuantity(side.size!.quantity);
    if (attachment case final exits?) {
      final tp = exits.takeProfit?.resolve(valuation.context, resolved);
      final sl = exits.stopLoss?.resolve(valuation.context, resolved);
      if (tp?.failure ?? sl?.failure case final failure?) {
        throw AccountReadFailure(failure);
      }
      resolved = resolved.withAttachment(
        LiveOrderAttachment(
          takeProfit: tp?.exit,
          stopLoss: sl?.exit,
          entryPeg: draft.attachment?.entryPeg,
        ),
      );
    }
    if (valuation.context.validate(resolved) case final failure?) {
      throw AccountReadFailure(failure);
    }
    return (draft: resolved, side: side);
  }
}

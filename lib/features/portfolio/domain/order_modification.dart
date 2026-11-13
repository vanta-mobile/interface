import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'aster_open_orders.dart';
import 'order_cancellation.dart';

/// Only resting LIMIT orders without TP/SL linkage can be modified; Aster's
/// `PUT /fapi/v3/order` rejects every other type.
bool canModifyOpenOrder(AsterOpenOrder order, {OpenOrderStrategy? strategy}) =>
    order.type == 'LIMIT' &&
    !order.closePosition &&
    order.price > Decimal.zero &&
    order.strategy == null &&
    strategy == null;

/// New absolute price and total quantity for one open order.
class OrderModification {
  const OrderModification({required this.order, required this.price, required this.quantity});
  final AsterOpenOrder order;
  final Decimal price, quantity;
}

enum OrderModifyOutcome {
  /// Aster returned, or a later query showed, the requested price and amount.
  modified,

  /// The order was verified to keep other terms, or the request never left.
  rejected,

  /// The request may have reached Aster and its state could not be read.
  unknown,
}

class OrderModificationResult {
  const OrderModificationResult(this.outcome, {this.order, this.closed = false, this.failure});
  final OrderModifyOutcome outcome;

  /// Verified open order after the attempt; null when it is no longer open.
  final AsterOpenOrder? order;

  /// The order was verified to be filled, cancelled or expired.
  final bool closed;
  final AccountReadFailure? failure;
}

abstract interface class OrderModificationRepository {
  Future<OrderModificationResult> modify({
    required String address,
    required OrderModification request,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  });
}

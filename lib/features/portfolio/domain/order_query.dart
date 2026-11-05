import 'futures_position_mode.dart';
import 'live_order.dart';

/// Frozen query expectations. Deliberately carries no balances, price snapshots,
/// signing credentials or actionable preflight context; it cannot be submitted.
class OrderQuery {
  const OrderQuery({
    required this.address,
    required this.symbol,
    required this.clientOrderId,
    required this.mode,
    required this.draft,
    this.protectedQuantity,
  });
  factory OrderQuery.capture(LiveOrderIntent intent) => OrderQuery(
    address: intent.context.address,
    symbol: intent.context.symbol,
    clientOrderId: intent.clientOrderId,
    mode: intent.mode,
    draft: intent.draft,
    protectedQuantity: intent.draft.attachment == null ? null : intent.draft.quantity,
  );
  final String address, symbol, clientOrderId;
  final FuturesPositionMode mode;
  final LiveOrderDraft draft;
  final String? protectedQuantity;
  String get key => '${address.toLowerCase()}:$clientOrderId';
  String get side => draft.buy ? 'BUY' : 'SELL';
  String get positionSide =>
      draft.closingSide ??
      (mode == FuturesPositionMode.oneWay
          ? 'BOTH'
          : draft.buy
          ? 'LONG'
          : 'SHORT');
}

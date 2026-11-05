import 'account_snapshot.dart';
import 'aster_open_orders.dart';

enum OrderCancelStep { idle, preparing, signing, submitting, checking, checkSigning }

class OrderResolution {
  const OrderResolution({
    required this.symbol,
    required this.orderId,
    required this.status,
    this.openOrder,
  });
  final String symbol, orderId, status;
  final AsterOpenOrder? openOrder;
  bool get terminal => const {'CANCELED', 'FILLED', 'EXPIRED', 'REJECTED'}.contains(status);
  bool get consistent => terminal
      ? openOrder == null
      : const {'NEW', 'PARTIALLY_FILLED'}.contains(status) &&
            openOrder?.symbol == symbol &&
            openOrder?.orderId == orderId &&
            openOrder?.status == status;
}

class OrderCancellationResult {
  const OrderCancellationResult({this.resolution, this.failure, this.newerOrderEvents = false});
  final OrderResolution? resolution;
  final AccountReadFailure? failure;
  final bool newerOrderEvents;
  bool get needsRecheck => resolution == null;
}

abstract interface class OrderCancellationRepository {
  Future<OrderCancellationResult> cancel({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  });
  Future<OrderCancellationResult> recheck({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  });
}

abstract interface class BatchOrderCancellationRepository {
  Future<BatchSymbolCancellation> cancelSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  });
  Future<BatchSymbolCancellation> recheckSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  });
}

class BatchSymbolCancellation {
  const BatchSymbolCancellation({
    required this.symbol,
    required this.submitted,
    this.snapshot,
    this.failure,
    this.newerOrderEvents = false,
  });
  final String symbol;
  final bool submitted;
  final AsterOpenOrders? snapshot;
  final AccountReadFailure? failure;
  final bool newerOrderEvents;
  bool get needsRecheck => submitted && snapshot == null;
}

class BatchCancelIntent {
  BatchCancelIntent({
    required this.address,
    required this.snapshot,
    required Iterable<String> symbols,
    required this.revision,
  }) : symbols = List.unmodifiable(symbols);
  final String address;
  final AsterOpenOrders snapshot;
  final List<String> symbols;
  final int revision;
  int get orderCount => snapshot.orders.where((o) => symbols.contains(o.symbol)).length;
  BatchCancelIntent atRevision(int value) =>
      BatchCancelIntent(address: address, snapshot: snapshot, symbols: symbols, revision: value);
}

class BatchCancellationState {
  BatchCancellationState({
    required this.intent,
    required Map<String, BatchSymbolCancellation> results,
    this.step = OrderCancelStep.idle,
    this.currentSymbol,
    this.stopRequested = false,
  }) : results = Map.unmodifiable(results);
  final BatchCancelIntent intent;
  final Map<String, BatchSymbolCancellation> results;
  final String? currentSymbol;
  final OrderCancelStep step;
  final bool stopRequested;
  bool get busy => step != OrderCancelStep.idle;
  bool get needsRecheck => results.values.any((r) => r.needsRecheck);
}

/// Captured before confirmation; a logout/reconnect invalidates the revision.
class OrderCancelIntent {
  const OrderCancelIntent({required this.address, required this.order, required this.revision});
  final String address;
  final AsterOpenOrder order;
  final int revision;
}

class OrderCancellationState {
  const OrderCancellationState({
    this.intent,
    this.step = OrderCancelStep.idle,
    this.result,
    this.failure,
    this.batch,
  });
  final OrderCancelIntent? intent;
  final OrderCancelStep step;
  final OrderCancellationResult? result;
  final AccountReadFailure? failure;
  final BatchCancellationState? batch;
  bool get busy => step != OrderCancelStep.idle || batch?.busy == true;
  bool get needsRecheck => result?.needsRecheck == true || batch?.needsRecheck == true;
}

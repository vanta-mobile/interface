import 'dart:async';

import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';

class TestBatchCancellationRepository implements BatchOrderCancellationRepository {
  final cancelled = <String>[];
  final checked = <String>[];
  final results = <String, BatchSymbolCancellation>{};
  final gates = <String, Completer<void>>{};
  BatchSymbolCancellation _result(String address, String symbol) =>
      results[symbol] ??
      BatchSymbolCancellation(
        symbol: symbol,
        submitted: true,
        snapshot: AsterOpenOrders(
          address: address,
          receivedAt: DateTime.utc(2026, 11, 2),
          orders: [],
        ),
      );

  @override
  Future<BatchSymbolCancellation> cancelSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) async {
    cancelled.add(symbol);
    onStep(OrderCancelStep.submitting);
    await gates[symbol]?.future;
    return _result(address, symbol);
  }

  @override
  Future<BatchSymbolCancellation> recheckSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) async {
    checked.add(symbol);
    onStep(OrderCancelStep.checkSigning);
    await gates[symbol]?.future;
    return _result(address, symbol);
  }
}

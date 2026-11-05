import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';

class TestOrderCancellationRepository implements OrderCancellationRepository {
  int cancels = 0, checks = 0;
  Completer<void>? gate;
  AccountReadFailure? failure;
  OrderCancellationResult result = const OrderCancellationResult(
    resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '1917641', status: 'CANCELED'),
  );
  @override
  Future<OrderCancellationResult> cancel({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) async {
    cancels++;
    onStep(OrderCancelStep.signing);
    await gate?.future;
    if (failure case final error?) throw error;
    return result;
  }

  @override
  Future<OrderCancellationResult> recheck({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) async {
    checks++;
    onStep(OrderCancelStep.checkSigning);
    await gate?.future;
    if (failure case final error?) throw error;
    return result;
  }
}

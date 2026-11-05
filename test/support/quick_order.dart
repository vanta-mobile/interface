import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/data/order_confirmation_preferences.dart';
import 'package:vanta/features/portfolio/domain/order_confirmation.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/domain/quick_order.dart';

import 'live_order.dart';

QuickOrderSizing quickSizing({
  LiveOrderContext? context,
  String fee = '0.0004',
  String cap = '100000',
  Iterable<AsterOpenOrder> orders = const [],
}) {
  final data = context ?? liveContext(bid: '79999', ask: '80001');
  return QuickOrderSizing(
    context: data,
    takerFee: Decimal.parse(fee),
    brackets: [LeverageBracket(maximum: 20, floor: Decimal.zero, cap: Decimal.parse(cap))],
    orders: AsterOpenOrders(address: data.address, receivedAt: data.receivedAt, orders: orders),
  );
}

class TestQuickOrderRepository implements QuickOrderRepository {
  int reads = 0;
  Completer<void>? gate;
  AccountReadFailure? failure;
  bool Function()? latestCurrent;
  @override
  Future<QuickOrderSizing> readSizing({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (failure case final value?) throw value;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    return quickSizing(context: context);
  }
}

class MemoryOrderConfirmationPreferences implements OrderConfirmationPreferences {
  final values = <OrderConfirmationKind, bool>{};
  bool get required => values[OrderConfirmationKind.market] ?? true;
  set required(bool value) => values[OrderConfirmationKind.market] = value;
  bool failRead = false, failWrite = false;
  int writes = 0;
  @override
  Future<bool> read(OrderConfirmationKind kind) async {
    if (failRead) throw StateError('read');
    return values[kind] ?? true;
  }

  @override
  Future<void> write(OrderConfirmationKind kind, bool value) async {
    writes++;
    if (failWrite) throw StateError('write');
    values[kind] = value;
  }
}

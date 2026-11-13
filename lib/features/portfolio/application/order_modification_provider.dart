import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_order_modification_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/order_cancellation.dart';
import '../domain/order_modification.dart';
import 'account_read_provider.dart';
import 'open_orders_provider.dart';
import 'order_cancellation_provider.dart';
import 'position_risk_provider.dart';

final orderModificationRepositoryProvider = Provider<OrderModificationRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedOrderModificationRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    verifier: ref.watch(orderCancellationRepositoryProvider),
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

final orderModificationProvider =
    NotifierProvider<OrderModificationController, OrderModificationState>(
      OrderModificationController.new,
    );

class OrderModificationState {
  const OrderModificationState({this.step = OrderCancelStep.idle, this.result});
  final OrderCancelStep step;
  final OrderModificationResult? result;
  bool get busy => step != OrderCancelStep.idle;
}

class OrderModificationController extends Notifier<OrderModificationState> {
  int _revision = 0;

  @override
  OrderModificationState build() {
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (previous, next) {
        if (previous == next) return;
        _revision++;
        state = const OrderModificationState();
      },
    );
    ref.onDispose(() => _revision++);
    return const OrderModificationState();
  }

  /// Whether [order] may be submitted for modification right now.
  bool available(AsterOpenOrder order) {
    final auth = ref.read(authProvider);
    final address = auth.identity?.walletAddress;
    final snapshot = ref.read(openOrdersReadProvider);
    final cancellation = ref.read(orderCancellationProvider);
    return !state.busy &&
        !auth.busy &&
        address != null &&
        auth.identity?.signingAvailable == true &&
        !cancellation.busy &&
        !cancellation.needsRecheck &&
        !snapshot.busy &&
        snapshot.account?.address.toLowerCase() == address.toLowerCase() &&
        snapshot.account?.orders.contains(order) == true;
  }

  /// Submits once. Returns null when the operation was superseded (logout,
  /// account switch or disposal) and its result must not be shown.
  Future<OrderModificationResult?> modify(OrderModification request) async {
    if (!available(request.order)) return null;
    final identity = ref.read(authProvider).identity!;
    final address = identity.walletAddress!;
    final revision = ++_revision;
    bool current() =>
        ref.mounted &&
        _revision == revision &&
        ref.read(authProvider).identity?.id == identity.id &&
        ref.read(authProvider).identity?.walletAddress == address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    final orders = ref.read(openOrdersReadProvider.notifier);
    final eventsAtStart = orders.eventRevision;
    state = const OrderModificationState(step: OrderCancelStep.preparing);
    OrderModificationResult result;
    try {
      result = await ref
          .read(orderModificationRepositoryProvider)
          .modify(
            address: address,
            request: request,
            isCurrent: current,
            onStep: (step) {
              if (current()) state = OrderModificationState(step: step);
            },
          );
    } on AccountReadFailure catch (failure) {
      // Raised only before the request could reach Aster.
      result = OrderModificationResult(
        OrderModifyOutcome.rejected,
        order: request.order,
        failure: failure,
      );
    } catch (_) {
      result = OrderModificationResult(
        OrderModifyOutcome.rejected,
        order: request.order,
        failure: const AccountReadFailure('accountReadFailed'),
      );
    }
    if (!current()) return null;
    final original = request.order;
    final snapshot = ref.read(openOrdersReadProvider).account;
    if (result.outcome == OrderModifyOutcome.unknown || snapshot == null) {
      orders.markStale();
    } else if (result.order != null || result.closed) {
      final updated = snapshot.orders
          .where((o) => o.symbol != original.symbol || o.orderId != original.orderId)
          .toList();
      if (result.order case final order?) updated.add(order);
      orders.applyVerifiedSnapshot(
        AsterOpenOrders(
          address: snapshot.address,
          receivedAt: snapshot.receivedAt,
          orders: updated,
          units: snapshot.units,
          lastEventAt: snapshot.lastEventAt,
        ),
        since: eventsAtStart,
        closed: result.closed ? [(original.symbol, original.orderId)] : const [],
      );
    }
    if (result.outcome != OrderModifyOutcome.rejected) {
      // Margin locked by the order changes; refresh without new wallet prompts.
      ref.read(accountReadProvider.notifier).markStale();
      ref.read(positionRiskProvider.notifier).markStale();
    }
    state = OrderModificationState(result: result);
    return result;
  }
}

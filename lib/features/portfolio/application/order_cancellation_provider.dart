import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_order_cancellation_repository.dart';
import '../data/signed_batch_cancellation_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/order_cancellation.dart';
import 'account_read_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';
import 'position_adl_provider.dart';

part 'batch_order_cancellation_controller.dart';

final batchOrderCancellationRepositoryProvider = Provider<BatchOrderCancellationRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedBatchCancellationRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

final orderCancellationRepositoryProvider = Provider<OrderCancellationRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedOrderCancellationRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

final orderCancellationProvider =
    NotifierProvider<OrderCancellationController, OrderCancellationState>(
      OrderCancellationController.new,
    );

class OrderCancellationController extends Notifier<OrderCancellationState>
    with BatchOrderCancellation {
  @override
  int _revision = 0;
  @override
  OrderCancellationState build() {
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
        state = const OrderCancellationState();
      },
    );
    ref.onDispose(() => _revision++);
    return const OrderCancellationState();
  }

  OrderCancelIntent? prepare(AsterOpenOrder order) {
    final auth = ref.read(authProvider);
    final identity = auth.identity;
    final snapshot = ref.read(openOrdersReadProvider);
    final address = identity?.walletAddress;
    if (state.busy ||
        state.needsRecheck ||
        auth.busy ||
        address == null ||
        identity?.signingAvailable != true ||
        snapshot.busy ||
        snapshot.account?.address.toLowerCase() != address.toLowerCase() ||
        snapshot.account?.orders.contains(order) != true) {
      return null;
    }
    return OrderCancelIntent(address: address, order: order, revision: _revision);
  }

  Future<void> cancel(OrderCancelIntent intent) => _run(intent, checkingOnly: false);

  Future<void> recheck() async {
    final intent = state.intent;
    if (intent == null || !state.needsRecheck) return;
    await _run(intent, checkingOnly: true);
  }

  Future<void> _run(OrderCancelIntent intent, {required bool checkingOnly}) async {
    if (state.busy || intent.revision != _revision) return;
    final auth = ref.read(authProvider);
    final identity = auth.identity;
    if (auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress != intent.address) {
      return;
    }
    if (!checkingOnly && (state.needsRecheck || prepare(intent.order) == null)) return;
    final revision = ++_revision;
    // The updated revision also keeps recheck tied to this operation.
    final active = OrderCancelIntent(
      address: intent.address,
      order: intent.order,
      revision: revision,
    );
    bool current() =>
        ref.mounted &&
        _revision == revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletAddress == intent.address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    state = OrderCancellationState(intent: active, step: OrderCancelStep.preparing);
    final repository = ref.read(orderCancellationRepositoryProvider);
    final eventsAtStart = ref.read(openOrdersReadProvider.notifier).eventRevision;
    try {
      final operation = checkingOnly ? repository.recheck : repository.cancel;
      var result = await operation(
        address: intent.address,
        order: intent.order,
        isCurrent: current,
        onStep: (step) {
          if (current()) state = OrderCancellationState(intent: active, step: step);
        },
      );
      if (!current()) return;
      final resolution = result.resolution;
      if (resolution != null &&
          (!resolution.consistent ||
              resolution.symbol != intent.order.symbol ||
              resolution.orderId != intent.order.orderId)) {
        result = const OrderCancellationResult(failure: AccountReadFailure('accountDataInvalid'));
      }
      if (ref.read(openOrdersReadProvider.notifier).hasEventAfter(intent.order, eventsAtStart)) {
        result = OrderCancellationResult(
          resolution: result.resolution,
          failure: result.failure,
          newerOrderEvents: true,
        );
      }
      if (result.resolution case final resolution?) {
        final snapshot = ref.read(openOrdersReadProvider).account;
        if (snapshot != null) {
          final updated = snapshot.orders
              .where((o) => o.symbol != resolution.symbol || o.orderId != resolution.orderId)
              .toList();
          if (resolution.openOrder case final order?) updated.add(order);
          ref
              .read(openOrdersReadProvider.notifier)
              .applyVerifiedSnapshot(
                AsterOpenOrders(
                  address: snapshot.address,
                  receivedAt: snapshot.receivedAt,
                  orders: updated,
                  units: snapshot.units,
                  lastEventAt: snapshot.lastEventAt,
                ),
                since: eventsAtStart,
                closed: resolution.terminal ? [(resolution.symbol, resolution.orderId)] : const [],
              );
        }
      } else {
        ref.read(openOrdersReadProvider.notifier).markStale();
      }
      // Do not trigger more wallet prompts just to refresh balances/positions.
      ref.read(accountReadProvider.notifier).markStale();
      ref.read(positionRiskProvider.notifier).markStale();
      ref.read(positionAdlProvider.notifier).markStale();
      state = OrderCancellationState(intent: active, result: result);
    } catch (error) {
      if (!current()) return;
      ref.read(openOrdersReadProvider.notifier).markStale();
      final failure = error is AccountReadFailure
          ? error
          : error is FormatException
          ? const AccountReadFailure('orderEventsCapacity')
          : const AccountReadFailure('accountReadFailed');
      state = checkingOnly || error is FormatException
          ? OrderCancellationState(
              intent: active,
              result: OrderCancellationResult(failure: failure),
            )
          : OrderCancellationState(intent: active, failure: failure);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_open_orders_repository.dart';
import '../domain/aster_open_orders.dart';
import '../domain/open_order_update.dart';
import '../domain/open_orders_event_book.dart';
import 'account_read_provider.dart';
import 'wallet_account_controller.dart';

final asterOpenOrdersRepositoryProvider = Provider<AsterOpenOrdersRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return SignedOpenOrdersRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final openOrdersReadProvider = NotifierProvider<OpenOrdersReadController, OpenOrdersReadState>(
  OpenOrdersReadController.new,
);

class OpenOrdersReadController extends WalletAccountController<AsterOpenOrders> {
  OpenOrdersEventBook _events = OpenOrdersEventBook();
  int _readRevision = 0;
  int get eventRevision => _events.revision;
  bool hasEventAfter(AsterOpenOrder order, int since) =>
      _events.hasEventAfter(order.symbol, order.orderId, since);
  bool hasSymbolEventAfter(String symbol, int since) => _events.hasSymbolEventAfter(symbol, since);
  @override
  void onScopeReset() {
    _events = OpenOrdersEventBook();
  }

  @override
  void onReadStarted() {
    _readRevision = _events.revision;
  }

  @override
  AsterOpenOrders reconcileSnapshot(AsterOpenOrders snapshot) =>
      _events.reconcile(snapshot, since: _readRevision);

  void applyEvent(OpenOrderUpdate event) {
    markStale();
    if (!_events.add(event)) return;
    final previous = state.account;
    if (previous == null) return;
    final updated = _events.reconcile(previous, since: _events.revision - 1);
    if (identical(previous, updated)) return;
    state = OpenOrdersReadState(
      account: updated,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }

  /// An accepted action may finish after a newer stream event. Reapply only
  /// events received during that operation plus terminal tombstones.
  void applyVerifiedSnapshot(
    AsterOpenOrders snapshot, {
    required int since,
    Iterable<(String, String)> closed = const [],
  }) {
    for (final (symbol, id) in closed) {
      _events.closeVerified(symbol, id);
    }
    super.acceptSnapshot(_events.reconcile(snapshot, since: since));
  }

  @override
  void acceptSnapshot(AsterOpenOrders snapshot) =>
      applyVerifiedSnapshot(snapshot, since: _events.revision);

  @override
  AsterOpenOrdersRepository get repository => ref.read(asterOpenOrdersRepositoryProvider);
}

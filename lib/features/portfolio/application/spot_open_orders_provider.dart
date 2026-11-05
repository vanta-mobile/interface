import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_spot_service.dart';
import '../data/signed_spot_open_orders_repository.dart';
import '../domain/spot_open_orders.dart';
import '../domain/spot_open_orders_event_book.dart';
import '../domain/account_snapshot.dart';
import 'account_read_provider.dart';
import 'wallet_account_controller.dart';

final spotOpenOrdersRepositoryProvider = Provider<SpotOpenOrdersRepository>((ref) {
  final service = AsterSpotService();
  ref.onDispose(service.close);
  return SignedSpotOpenOrdersRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});
final spotOpenOrdersProvider = NotifierProvider<SpotOpenOrdersController, SpotOpenOrdersState>(
  SpotOpenOrdersController.new,
);

class SpotOpenOrdersController extends WalletAccountController<SpotOpenOrders> {
  SpotOpenOrdersEventBook _events = SpotOpenOrdersEventBook();
  int _readRevision = 0;
  @override
  void onScopeReset() => _events = SpotOpenOrdersEventBook();
  @override
  void onReadStarted() => _readRevision = _events.revision;
  @override
  SpotOpenOrders reconcileSnapshot(SpotOpenOrders snapshot) =>
      _events.reconcile(snapshot, since: _readRevision);
  void applyEvent(SpotOpenOrderUpdate event) {
    markStale();
    try {
      if (!_events.add(event)) return;
    } on FormatException {
      throw const AccountReadFailure('spotOpenOrdersCapacity');
    }
    final old = state.account;
    if (old == null) return;
    final next = _events.reconcile(old, since: _events.revision - 1);
    if (identical(old, next)) return;
    state = SpotOpenOrdersState(
      account: next,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }

  @override
  SpotOpenOrdersRepository get repository => ref.read(spotOpenOrdersRepositoryProvider);
}

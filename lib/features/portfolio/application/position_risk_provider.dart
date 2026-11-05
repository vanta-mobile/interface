import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_position_risk_repository.dart';
import '../domain/position_risk.dart';
import '../domain/account_update.dart';
import '../domain/account_update_book.dart';
import '../domain/account_event_reconciliation.dart';
import 'account_read_provider.dart';
import 'wallet_account_controller.dart';

final positionRiskRepositoryProvider = Provider<PositionRiskRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return SignedPositionRiskRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final positionRiskProvider =
    NotifierProvider<PositionRiskController, AccountSnapshotState<PositionRiskSnapshot>>(
      PositionRiskController.new,
    );

class PositionRiskController extends WalletAccountController<PositionRiskSnapshot> {
  AccountUpdateBook _events = AccountUpdateBook();
  int _readRevision = 0;
  @override
  void onScopeReset() => _events = AccountUpdateBook();
  @override
  void onReadStarted() => _readRevision = _events.revision;
  @override
  PositionRiskSnapshot reconcileSnapshot(PositionRiskSnapshot snapshot) =>
      reconcileRiskUpdates(snapshot, _events, since: _readRevision);

  void applyEvent(AccountUpdate event) {
    markStale();
    if (!_events.add(event)) return;
    final previous = state.account;
    if (previous == null) return;
    final updated = reconcileRiskUpdates(previous, _events, since: _events.revision - 1);
    if (identical(previous, updated)) return;
    state = AccountSnapshotState<PositionRiskSnapshot>(
      account: updated,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }

  @override
  PositionRiskRepository get repository => ref.read(positionRiskRepositoryProvider);
}

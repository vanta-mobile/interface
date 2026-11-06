import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_account_repository.dart';
import '../domain/aster_account.dart';
import '../domain/account_update.dart';
import '../domain/account_update_book.dart';
import '../domain/account_event_reconciliation.dart';
import 'wallet_account_controller.dart';

final asterReadNoncesProvider = Provider<AsterReadNonces>((_) => AsterReadNonces());

final asterAccountRepositoryProvider = Provider<AsterAccountRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedAccountRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

final accountReadProvider = NotifierProvider<AccountReadController, AccountReadState>(
  AccountReadController.new,
);

class AccountReadController extends WalletAccountController<AsterAccount> {
  AccountUpdateBook _events = AccountUpdateBook();
  int _readRevision = 0;
  @override
  void onScopeReset() => _events = AccountUpdateBook();
  @override
  void onReadStarted() => _readRevision = _events.revision;
  @override
  AsterAccount reconcileSnapshot(AsterAccount snapshot) =>
      reconcileAccountUpdates(snapshot, _events, since: _readRevision);

  void applyEvent(AccountUpdate event) {
    markStale();
    if (!_events.add(event)) return;
    final previous = state.account;
    if (previous == null) return;
    final updated = reconcileAccountUpdates(previous, _events, since: _events.revision - 1);
    if (identical(previous, updated)) return;
    state = AccountReadState(
      account: updated,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }

  @override
  AsterAccountRepository get repository => ref.read(asterAccountRepositoryProvider);
}

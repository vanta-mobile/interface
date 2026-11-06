import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../notifications/application/notification_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/signed_transfer_history_repository.dart';
import '../domain/transfer_history.dart';

final transferHistoryRepositoryProvider = Provider<TransferHistoryRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedTransferHistoryRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
  );
});

class TransferHistoryState extends AccountSnapshotState<TransferHistory> {
  const TransferHistoryState({
    super.account,
    super.step,
    super.failure,
    super.stale,
    this.initialBaseline = false,
  });
  final bool initialBaseline;
}

final transferHistoryProvider = NotifierProvider<TransferHistoryController, TransferHistoryState>(
  TransferHistoryController.new,
);

/// Events only request a refresh. Private reads always follow an explicit tap.
class TransferHistoryController extends Notifier<TransferHistoryState> {
  int _generation = 0, _revision = 0;
  @override
  TransferHistoryState build() {
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (before, after) {
        if (before != after) {
          _generation++;
          state = const TransferHistoryState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const TransferHistoryState();
  }

  void markRefreshNeeded() {
    _revision++;
    state = TransferHistoryState(
      account: state.account,
      step: state.step,
      failure: state.failure,
      stale: true,
      initialBaseline: state.initialBaseline,
    );
  }

  void stop() {
    _generation++;
    state = TransferHistoryState(
      account: state.account,
      stale: true,
      failure: const AccountReadFailure('historyReadStopped'),
    );
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider), identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (state.busy || auth.busy || address == null || identity == null) return;
    if (!identity.signingAvailable) {
      state = TransferHistoryState(
        account: state.account,
        stale: true,
        failure: const AccountReadFailure('authWalletReconnect'),
      );
      return;
    }
    final generation = ++_generation, revision = _revision;
    bool current() =>
        ref.mounted &&
        _generation == generation &&
        ref.read(authProvider).identity?.id == identity.id &&
        ref.read(authProvider).identity?.walletAddress == address;
    state = TransferHistoryState(
      account: state.account,
      step: AccountReadStep.preparing,
      stale: state.stale,
    );
    try {
      final inbox = ref.read(notificationRepositoryProvider);
      if (!inbox.snapshot.loaded || inbox.snapshot.storageFailed) await inbox.reload();
      if (!current()) return;
      if (!inbox.snapshot.loaded || inbox.snapshot.storageFailed) {
        throw const AccountReadFailure('transferStorageRequired');
      }
      final history = await ref
          .read(transferHistoryRepositoryProvider)
          .read(
            address: address,
            isCurrent: current,
            onStep: (step) {
              if (current()) {
                state = TransferHistoryState(
                  account: state.account,
                  step: step,
                  stale: state.stale,
                );
              }
            },
          );
      if (!current()) return;
      if (history.address.toLowerCase() != address.toLowerCase()) {
        throw const AccountReadFailure('authWalletChanged');
      }
      final initial = await inbox.observeTransfers(
        address,
        history.records,
        history.receivedAt,
        isCurrent: current,
      );
      if (!current()) return;
      state = TransferHistoryState(
        account: history,
        initialBaseline: initial,
        stale: revision != _revision,
        failure: inbox.snapshot.storageFailed
            ? const AccountReadFailure('transferStorageRequired')
            : null,
      );
    } catch (error) {
      if (!current()) return;
      state = TransferHistoryState(
        account: state.account,
        stale: true,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/account_snapshot.dart';

abstract class WalletAccountController<T extends WalletAccountSnapshot>
    extends Notifier<AccountSnapshotState<T>> {
  WalletAccountRepository<T> get repository;

  void onScopeReset() {}
  void onReadStarted() {}
  T reconcileSnapshot(T snapshot) => snapshot;

  int _generation = 0;
  int _staleRevision = 0;
  Timer? _expiry;
  @override
  AccountSnapshotState<T> build() {
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
        if (before == after) return;
        _generation++;
        _expiry?.cancel();
        onScopeReset();
        state = AccountSnapshotState<T>();
      },
    );
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return AccountSnapshotState<T>();
  }

  Future<void> refresh() async {
    if (state.busy) return;
    final identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (identity == null || address == null) return;
    if (!identity.signingAvailable) {
      state = AccountSnapshotState<T>(failure: const AccountReadFailure('authWalletReconnect'));
      return;
    }
    final previous = state.account;
    onReadStarted();
    final staleRevision = _staleRevision;
    final generation = ++_generation;
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        ref.read(authProvider).identity?.id == identity.id &&
        ref.read(authProvider).identity?.walletAddress == address;
    state = AccountSnapshotState<T>(
      account: previous,
      step: AccountReadStep.preparing,
      stale: previous != null,
    );
    try {
      final account = await repository.read(
        address: address,
        isCurrent: current,
        onStep: (step) {
          if (current()) {
            state = AccountSnapshotState<T>(
              account: state.account,
              step: step,
              stale: state.account != null,
            );
          }
        },
      );
      if (!current()) return;
      if (account.address.toLowerCase() != address.toLowerCase()) {
        throw const AccountReadFailure('authWalletChanged');
      }
      final reconciled = reconcileSnapshot(account);
      state = AccountSnapshotState<T>(
        account: reconciled,
        stale: staleRevision != _staleRevision || !identical(reconciled, account),
      );
      _expiry?.cancel();
      _expiry = Timer(const Duration(seconds: 30), () => markStale());
    } catch (error) {
      if (!current()) return;
      state = AccountSnapshotState<T>(
        account: state.account,
        stale: state.account != null,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }

  /// Stop waiting without implying the wallet dialog itself was dismissed.
  /// The repository's scope checks prevent a late signature from being sent.
  void stopRead() {
    if (!ref.mounted || !state.busy) return;
    _generation++;
    _expiry?.cancel();
    state = AccountSnapshotState<T>(account: state.account, stale: state.account != null);
  }

  void markStale() {
    _staleRevision++;
    if (!ref.mounted || state.account == null || state.stale) return;
    state = AccountSnapshotState<T>(
      account: state.account,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }

  /// A verified order action invalidates any older in-flight snapshot read.
  void acceptSnapshot(T snapshot) {
    _generation++;
    _expiry?.cancel();
    state = AccountSnapshotState<T>(account: snapshot, stale: true);
  }
}

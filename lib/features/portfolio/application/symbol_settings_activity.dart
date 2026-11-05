import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import 'order_recovery_provider.dart';
import 'position_margin_storage_provider.dart';
import 'rebalance_storage_provider.dart';
import '../../funding/application/internal_transfer_storage_provider.dart';

enum SymbolSetting {
  leverage,
  marginMode,
  positionMargin,
  positionMode,
  assetMode,
  order,
  batchClose,
  scaled,
  recovery,
  rebalance,
  internalTransfer,
}

class SymbolSettingsActivity {
  const SymbolSettingsActivity({
    this.owner,
    this.busy = false,
    this.unresolved = false,
    this.epoch = 0,
    this.recoveryBlocked = false,
  });
  final SymbolSetting? owner;
  final bool busy, unresolved;
  final int epoch;
  final bool recoveryBlocked;
  bool blocks(SymbolSetting setting) => recoveryBlocked || owner != null && owner != setting;
}

/// Serializes actual settings operations, including unknown outcomes, across
/// account-wide and symbol-scoped routes. A new setting cannot supersede an unresolved write.
final symbolSettingsActivityProvider =
    NotifierProvider<SymbolSettingsActivityController, SymbolSettingsActivity>(
      SymbolSettingsActivityController.new,
    );

class SymbolSettingsActivityController extends Notifier<SymbolSettingsActivity> {
  int _token = 0;
  bool get _recoveryBlocked {
    final storage = ref.read(orderRecoverySnapshotProvider);
    final rebalances = ref.read(rebalanceStorageProvider);
    final transfers = ref.read(internalTransferStorageProvider);
    final margins = ref.read(positionMarginStorageProvider);
    return !margins.ready ||
        margins.failed ||
        ref.read(currentPositionMarginsProvider).any((r) => !r.acknowledged) ||
        !transfers.ready ||
        transfers.failure ||
        ref.read(pendingInternalTransfersProvider).isNotEmpty ||
        !rebalances.ready ||
        rebalances.failure ||
        ref.read(pendingRebalancesProvider).isNotEmpty ||
        !storage.ready ||
        storage.failure != null ||
        ref.read(pendingWalletOrdersProvider).isNotEmpty;
  }

  @override
  SymbolSettingsActivity build() {
    void updateRecovery() {
      state = SymbolSettingsActivity(
        owner: state.owner,
        busy: state.busy,
        unresolved: state.unresolved,
        epoch: state.epoch,
        recoveryBlocked: _recoveryBlocked,
      );
    }

    ref.listen(positionMarginStorageProvider, (a, b) => updateRecovery());
    ref.listen(currentPositionMarginsProvider, (a, b) => updateRecovery());
    ref.listen(internalTransferStorageProvider, (a, b) => updateRecovery());
    ref.listen(pendingInternalTransfersProvider, (a, b) => updateRecovery());
    ref.listen(rebalanceStorageProvider, (a, b) => updateRecovery());
    ref.listen(pendingRebalancesProvider, (a, b) => updateRecovery());
    ref.listen(orderRecoverySnapshotProvider, (a, b) => updateRecovery());
    ref.listen(pendingWalletOrdersProvider, (a, b) => updateRecovery());
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
        _token++;
        state = SymbolSettingsActivity(epoch: state.epoch + 1, recoveryBlocked: _recoveryBlocked);
      },
    );
    return SymbolSettingsActivity(recoveryBlocked: _recoveryBlocked);
  }

  int? acquire(SymbolSetting owner, {bool checkingOnly = false}) {
    final storage = ref.read(orderRecoverySnapshotProvider);
    final rebalances = ref.read(rebalanceStorageProvider);
    final transfers = ref.read(internalTransferStorageProvider);
    final margins = ref.read(positionMarginStorageProvider);
    if (!margins.ready ||
        margins.failed ||
        ref.read(currentPositionMarginsProvider).any((r) => !r.acknowledged) && !checkingOnly ||
        !transfers.ready ||
        transfers.failure ||
        ref.read(pendingInternalTransfersProvider).isNotEmpty && !checkingOnly ||
        !rebalances.ready ||
        rebalances.failure ||
        ref.read(pendingRebalancesProvider).isNotEmpty && !checkingOnly ||
        !storage.ready ||
        storage.failure != null ||
        ref.read(pendingWalletOrdersProvider).isNotEmpty && !checkingOnly) {
      return null;
    }
    if (state.busy ||
        state.owner != null && state.owner != owner ||
        state.unresolved && !checkingOnly) {
      return null;
    }
    state = SymbolSettingsActivity(
      owner: owner,
      busy: true,
      epoch: state.epoch,
      recoveryBlocked: _recoveryBlocked,
    );
    return ++_token;
  }

  void submitted(int token) {
    if (!ref.mounted || token != _token) return;
    state = SymbolSettingsActivity(
      owner: state.owner,
      busy: true,
      epoch: state.epoch + 1,
      recoveryBlocked: _recoveryBlocked,
    );
  }

  void finish(int token, {required bool unresolved}) {
    if (!ref.mounted || token != _token) return;
    state = SymbolSettingsActivity(
      owner: unresolved ? state.owner : null,
      unresolved: unresolved,
      epoch: state.epoch,
      recoveryBlocked: _recoveryBlocked,
    );
  }
}

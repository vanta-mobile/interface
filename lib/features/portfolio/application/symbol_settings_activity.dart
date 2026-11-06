import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart' show quoteUpdatesActiveProvider;
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

/// A wallet prompt can background the app without ending its active order.
/// Keep existing public/private connections; their expiry and event guards
/// remain authoritative if the OS suspends delivery or the connection drops.
final orderSessionActiveProvider = Provider.autoDispose<bool>((ref) {
  final foreground = ref.watch(quoteUpdatesActiveProvider);
  final operation = ref.watch(symbolSettingsActivityProvider);
  return orderSessionActive(foreground, operation);
});

bool orderSessionActive(bool foreground, SymbolSettingsActivity operation) =>
    foreground || operation.busy && operation.owner == SymbolSetting.order;

class SymbolSettingsActivityController extends Notifier<SymbolSettingsActivity> {
  int _token = 0;
  SymbolSettingsActivity _operation = const SymbolSettingsActivity();
  Object? _identityKey;
  bool get _recoveryBlocked => _hasRecoveryBlock();

  bool _hasRecoveryBlock({String? activeOrderId}) {
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
        ref.read(pendingWalletOrdersProvider).any((r) => r.query.clientOrderId != activeOrderId);
  }

  /// The active order must persist its own recovery record before POST. That
  /// record blocks other work, but must not invalidate the write which owns it.
  /// Storage failures and every other pending operation still block the send.
  bool canContinueOrder(String clientOrderId) =>
      state.owner == SymbolSetting.order &&
      state.busy &&
      !state.unresolved &&
      !_hasRecoveryBlock(activeOrderId: clientOrderId);

  @override
  SymbolSettingsActivity build() {
    final identityKey = ref.watch(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
    );
    if (_identityKey != null && _identityKey != identityKey) {
      _token++;
      _operation = SymbolSettingsActivity(epoch: _operation.epoch + 1);
    }
    _identityKey = identityKey;
    // Derive recovery state during provider rebuilds. A wallet-scoped pending
    // list can rebuild lazily while a widget renders after logout; writing this
    // notifier from its listener would mutate state during widget build.
    ref.watch(positionMarginStorageProvider);
    ref.watch(currentPositionMarginsProvider);
    ref.watch(internalTransferStorageProvider);
    ref.watch(pendingInternalTransfersProvider);
    ref.watch(rebalanceStorageProvider);
    ref.watch(pendingRebalancesProvider);
    ref.watch(orderRecoverySnapshotProvider);
    ref.watch(pendingWalletOrdersProvider);
    return SymbolSettingsActivity(
      owner: _operation.owner,
      busy: _operation.busy,
      unresolved: _operation.unresolved,
      epoch: _operation.epoch,
      recoveryBlocked: _recoveryBlocked,
    );
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
    state = _operation = SymbolSettingsActivity(
      owner: owner,
      busy: true,
      epoch: state.epoch,
      recoveryBlocked: _recoveryBlocked,
    );
    return ++_token;
  }

  void submitted(int token) {
    if (!ref.mounted || token != _token) return;
    state = _operation = SymbolSettingsActivity(
      owner: state.owner,
      busy: true,
      epoch: state.epoch + 1,
      recoveryBlocked: _recoveryBlocked,
    );
  }

  void finish(int token, {required bool unresolved}) {
    if (!ref.mounted || token != _token) return;
    state = _operation = SymbolSettingsActivity(
      owner: unresolved ? state.owner : null,
      unresolved: unresolved,
      epoch: state.epoch,
      recoveryBlocked: _recoveryBlocked,
    );
  }
}

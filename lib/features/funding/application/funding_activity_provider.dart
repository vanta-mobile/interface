import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';
import '../domain/deposit_approval.dart' show DepositReceiptStatus;
import '../domain/funding_activity.dart';
import '../domain/transfer_history.dart';
import '../domain/withdrawal_recovery.dart';
import 'deposit_submission_provider.dart';
import 'transfer_history_provider.dart';

/// Retains observed pending records across empty/failed refreshes and routes.
/// Only explicit final evidence emits a completion, once per identity session.
final fundingActivityProvider = NotifierProvider<FundingActivityController, FundingActivityState>(
  FundingActivityController.new,
);

class FundingActivityController extends Notifier<FundingActivityState> {
  final _pending = <String, FundingActivity>{};
  final _finished = <String>{};
  final _aliases = <String, String>{};
  final _local = <String, FundingActivity>{};
  final _liveWithdrawals = <String>{};
  final _silentWithdrawals = <String>{};

  @override
  FundingActivityState build() {
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress?.toLowerCase(), s.identity?.walletKind),
      ),
      (before, after) {
        if (before == after) return;
        _pending.clear();
        _finished.clear();
        _aliases.clear();
        _local.clear();
        _liveWithdrawals.clear();
        _silentWithdrawals.clear();
        state = FundingActivityState();
        _sync();
      },
    );
    // Journal events must not be lost while the portfolio route is covered
    // (Riverpod pauses UI subscriptions). Remember newly prepared attempts.
    final operations = ref.watch(walletOperationJournalProvider).changes.listen((snapshot) {
      final address = ref.read(authProvider).identity?.walletAddress?.toLowerCase();
      for (final r in snapshot.records) {
        if (!r.acknowledged &&
            r.kind == WalletOperationKind.withdrawal &&
            r.address.toLowerCase() == address) {
          _liveWithdrawals.add(r.key);
        }
      }
    });
    ref.onDispose(() => unawaited(operations.cancel()));
    ref.listen(transferHistoryProvider, (_, _) => _sync());
    ref.listen(pendingDepositSubmissionsProvider, (_, _) => _sync());
    ref.listen(currentWalletOperationsProvider, (_, _) => _sync());
    ref.listen(depositSubmissionProvider, (_, _) => _sync());
    scheduleMicrotask(() {
      if (ref.mounted) _sync();
    });
    return FundingActivityState();
  }

  void _sync() {
    final address = ref.read(authProvider).identity?.walletAddress?.toLowerCase();
    if (address == null) return;
    final completions = [...state.completions];
    void add(FundingActivity a) {
      if (a.deposit != null || a.withdrawal != null) _local[a.key] = a;
      if (!_finished.contains(a.key)) _pending[a.key] = a;
    }

    void finish(String key, TransferStatus status) {
      if (!_finished.add(key)) return;
      final activity = _pending.remove(key);
      if (activity != null && !_silentWithdrawals.remove(key)) {
        completions.add(FundingCompletion(activity, status));
      }
    }

    for (final r in ref.read(pendingDepositSubmissionsProvider)) {
      if (r.hash != null && r.transaction.from.toLowerCase() == address) {
        add(FundingActivity.fromDeposit(r));
      }
    }
    for (final r in ref.read(currentWalletOperationsProvider)) {
      if (r.address.toLowerCase() != address || r.kind != WalletOperationKind.withdrawal) continue;
      if (!r.acknowledged) {
        _liveWithdrawals.add(r.key);
      } else if (r.reference != null) {
        final activity = FundingActivity.fromWithdrawal(r);
        // Acknowledged recovery journals also retain old completed requests.
        // Their first terminal snapshot is a baseline, not a new notification.
        if (!_local.containsKey(activity.key) && !_liveWithdrawals.contains(r.key)) {
          _silentWithdrawals.add(activity.key);
        }
        add(activity);
      }
    }
    final deposit = ref.read(depositSubmissionProvider);
    final localDeposit = deposit.record;
    if (localDeposit?.transaction.from.toLowerCase() == address) {
      if (deposit.credited) {
        finish('deposit:${localDeposit!.key}', TransferStatus.success);
      } else if (deposit.receipt?.status == DepositReceiptStatus.reverted ||
          deposit.receipt?.status == DepositReceiptStatus.replaced) {
        finish('deposit:${localDeposit!.key}', TransferStatus.failed);
      }
    }
    final snapshot = ref.read(transferHistoryProvider);
    final history = snapshot.account;
    if (history != null &&
        history.address.toLowerCase() == address &&
        !snapshot.stale &&
        !snapshot.busy &&
        snapshot.failure == null) {
      // Alias server records to their exact local journal entry. Remember the
      // alias after journal completion so a later refresh cannot reintroduce it.
      for (final a in _local.values) {
        final match = a.deposit != null
            ? reconcileDeposit(a.deposit!, history)
            : a.withdrawal != null
            ? reconcileWithdrawal(a.withdrawal!, history)
            : null;
        if (match != null) {
          final serverKey = 'history:${match.key}';
          _aliases[serverKey] = a.key;
          _pending.remove(serverKey);
        }
      }
      for (final r in history.records) {
        final serverKey = 'history:${r.key}',
            key = _aliases['history:${r.key}'] ?? 'history:${r.key}';
        if (_finished.contains(key)) continue;
        if (r.status == TransferStatus.processing) {
          _silentWithdrawals.remove(key);
          if (key == serverKey) add(FundingActivity.fromTransfer(r));
        } else {
          final old = _pending[key];
          // A reused ID with changed terms cannot settle a tracked transfer.
          if (old != null &&
              old.type == r.type &&
              old.asset == r.asset &&
              old.amount == r.amount &&
              (old.transfer == null || old.transfer!.chainId == r.chainId)) {
            finish(key, r.status);
          }
        }
      }
    }
    final rows = _pending.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = FundingActivityState(pending: rows, completions: completions);
  }

  /// Called only when a visible toast has been accepted for display.
  void acknowledgeCompletion(String key) {
    state = FundingActivityState(
      pending: state.pending,
      completions: state.completions.where((c) => c.activity.key != key),
    );
  }
}

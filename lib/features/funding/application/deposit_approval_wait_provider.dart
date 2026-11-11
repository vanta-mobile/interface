import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_approval.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_approval_provider.dart';
import 'deposit_wallet_provider.dart';

class DepositApprovalWaitState {
  const DepositApprovalWaitState({this.record, this.failure});
  final DepositApprovalRecord? record;
  final AccountReadFailure? failure;
  bool get busy => record != null;
}

/// The first family argument is owned by a single deposit page instance.
/// Reopening the page never adopts a pending journal as a loading state.
final depositApprovalWaitProvider = NotifierProvider.autoDispose
    .family<DepositApprovalWaitController, DepositApprovalWaitState, (Object, DepositWalletQuery)>(
      DepositApprovalWaitController.new,
    );

class DepositApprovalWaitController extends Notifier<DepositApprovalWaitState> {
  DepositApprovalWaitController(this.scope);
  final (Object, DepositWalletQuery) scope;

  @override
  DepositApprovalWaitState build() {
    ref.watch(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)));
    ref.listen(depositWalletProvider(scope.$2), (_, after) => _observeWallet(after));
    ref.listen(depositApprovalProvider, (_, after) {
      final record = state.record;
      if (record == null || after.record?.key != record.key || after.busy) return;
      if (after.failure case final key?) {
        state = DepositApprovalWaitState(
          failure: AccountReadFailure(key, details: after.errorDetails),
        );
        return;
      }
      switch (after.receipt?.status) {
        case DepositReceiptStatus.reverted:
          state = const DepositApprovalWaitState(
            failure: AccountReadFailure('depositApprovalReceiptReverted'),
          );
        case DepositReceiptStatus.replaced:
          state = const DepositApprovalWaitState(
            failure: AccountReadFailure('depositApprovalReceiptReplaced'),
          );
        case DepositReceiptStatus.succeeded:
          unawaited(ref.read(depositWalletProvider(scope.$2).notifier).refresh());
        default:
          break;
      }
    });
    return const DepositApprovalWaitState();
  }

  void start(DepositApprovalRecord record) {
    if (record.hash == null || !record.query.sameAsset(scope.$2)) return;
    state = DepositApprovalWaitState(record: record);
    _observeWallet(ref.read(depositWalletProvider(scope.$2)));
  }

  void clear() => state = const DepositApprovalWaitState();

  void _observeWallet(AccountSnapshotState<DepositWalletSnapshot> wallet) {
    final record = state.record;
    if (record == null || wallet.busy) return;
    if (wallet.failure case final failure?) {
      state = DepositApprovalWaitState(failure: failure);
      return;
    }
    final snapshot = wallet.account, allowance = wallet.account?.allowanceUnits;
    if (wallet.stale ||
        snapshot == null ||
        allowance == null ||
        !snapshot.query.sameAsset(record.query) ||
        snapshot.address.toLowerCase() != record.transaction.from.toLowerCase() ||
        snapshot.receivedAt.isBefore(record.preparedAt) ||
        snapshot.blockNumber < record.baseBlock) {
      return;
    }
    final confirmed =
        allowance >= record.amountUnits ||
        record.kind == DepositTransactionKind.resetApproval && allowance == BigInt.zero;
    if (confirmed) state = const DepositApprovalWaitState();
  }
}

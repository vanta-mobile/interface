import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../portfolio/application/rebalance_provider.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../domain/deposit_approval.dart' show DepositReceiptStatus;
import '../domain/deposit_wallet.dart';
import '../domain/transfer_history.dart';
import '../domain/withdrawal_recovery.dart';
import 'deposit_approval_provider.dart';
import 'deposit_submission_provider.dart';
import 'deposit_wallet_provider.dart';
import 'transfer_history_provider.dart';
import 'withdraw_info_provider.dart';

/// Public RPC reads only: the deposit form keeps its wallet balance and
/// allowance current while visible. Failures wait for an explicit refresh.
final depositWalletAutoReadProvider = Provider.autoDispose.family<void, DepositWalletQuery>((
  ref,
  query,
) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  final wallet = ref.watch(depositWalletProvider(query));
  if (address == null || wallet.busy || wallet.failure != null) return;
  if (wallet.account != null && !wallet.stale) return;
  scheduleMicrotask(() {
    if (ref.mounted) unawaited(ref.read(depositWalletProvider(query).notifier).refresh());
  });
});

/// Whether private account reads can run without opening the wallet.
final fundingSilentReadsProvider = Provider.autoDispose<bool>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.busy || auth.needsWalletConnection) return false;
  return ref.watch(tradingAgentProvider).asData?.value?.status == TradingAgentStatus.active;
});

/// Only an active device grant loads withdrawal limits and the Rebalance
/// check on entry. Navigation never asks the wallet for a signature.
final withdrawAutoLoadProvider = Provider.autoDispose<void>((ref) {
  if (!ref.watch(fundingSilentReadsProvider)) return;
  final entry = ref.watch(activeAccountEntryProvider);
  if (entry != null && entry.roleKnown && !entry.main) return;
  final info = ref.watch(withdrawInfoProvider);
  final rebalance = ref.watch(rebalanceProvider);
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    if (info.account == null && info.failure == null && !info.busy) {
      unawaited(ref.read(withdrawInfoProvider.notifier).refresh());
    }
    if (rebalance.context == null && rebalance.failure == null && !rebalance.busy) {
      unawaited(ref.read(rebalanceProvider.notifier).load());
    }
  });
});

final depositReceiptPollIntervalProvider = Provider<Duration>((_) => const Duration(seconds: 6));

/// Checks canonical receipts of this wallet's hashed approval and deposit
/// records while a funding page is visible. It never signs, resends or drops
/// a record; a controller in review or send is left untouched.
final depositReceiptWatchProvider = Provider.autoDispose<void>((ref) {
  void poll() {
    if (!ref.mounted || !_foreground()) return;
    final approval = ref.read(depositApprovalProvider);
    final pendingApproval = ref
        .read(pendingDepositApprovalsProvider)
        .where((r) => r.hash != null)
        .firstOrNull;
    if (pendingApproval != null && approval.step == DepositApprovalStep.idle) {
      unawaited(ref.read(depositApprovalProvider.notifier).check(pendingApproval.key, ''));
    }
    final submission = ref.read(depositSubmissionProvider);
    final pendingDeposit = ref
        .read(pendingDepositSubmissionsProvider)
        .where((r) => r.hash != null)
        .firstOrNull;
    final chainDone =
        submission.record?.key == pendingDeposit?.key &&
        submission.receipt?.status == DepositReceiptStatus.succeeded;
    if (pendingDeposit != null && !chainDone && submission.step == DepositSubmissionStep.idle) {
      unawaited(ref.read(depositSubmissionProvider.notifier).check(pendingDeposit.key, ''));
    }
  }

  final timer = Timer.periodic(ref.watch(depositReceiptPollIntervalProvider), (_) => poll());
  ref.onDispose(timer.cancel);
});

/// Polling pauses while the app is not in the foreground.
bool _foreground() {
  final state = SchedulerBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

final fundingStatusPollIntervalProvider = Provider<Duration>((_) => const Duration(seconds: 10));

/// After its chain receipt succeeds, rechecks platform credit of one deposit
/// through the device grant until the exact SUCCESS record completes it.
final depositCreditWatchProvider = Provider.autoDispose.family<void, String>((ref, key) {
  if (!ref.watch(fundingSilentReadsProvider)) return;
  void poll() {
    if (!ref.mounted || !_foreground()) return;
    final state = ref.read(depositSubmissionProvider);
    final pending = ref.read(pendingDepositSubmissionsProvider).any((r) => r.key == key);
    final chainDone =
        state.record?.key == key && state.receipt?.status == DepositReceiptStatus.succeeded;
    if (!pending || !chainDone || state.credited || state.step != DepositSubmissionStep.idle) {
      return;
    }
    unawaited(ref.read(depositSubmissionProvider.notifier).checkCredit(key));
  }

  final timer = Timer.periodic(ref.watch(fundingStatusPollIntervalProvider), (_) => poll());
  ref.onDispose(timer.cancel);
});

/// Rereads signed history through the device grant until the withdrawal's
/// request ID resolves to a final status. Without a grant nothing runs here.
final withdrawalStatusWatchProvider = Provider.autoDispose.family<void, WalletOperationRecord>((
  ref,
  record,
) {
  if (!ref.watch(fundingSilentReadsProvider)) return;
  void poll() {
    if (!ref.mounted || !_foreground()) return;
    final history = ref.read(transferHistoryProvider);
    if (history.busy) return;
    final status = history.account == null || history.stale
        ? null
        : reconcileWithdrawal(record, history.account!)?.status;
    if (status == TransferStatus.success || status == TransferStatus.failed) return;
    unawaited(ref.read(transferHistoryProvider.notifier).refresh());
  }

  scheduleMicrotask(poll);
  final timer = Timer.periodic(ref.watch(fundingStatusPollIntervalProvider), (_) => poll());
  ref.onDispose(timer.cancel);
});

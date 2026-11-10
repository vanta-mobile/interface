import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../domain/deposit_approval.dart' show DepositReceiptStatus;
import 'deposit_submission_provider.dart';
import 'funding_activity_provider.dart';
import 'funding_flow_provider.dart';
import 'transfer_history_provider.dart';

/// Read-only progress refresh. Shared history reads coalesce with other routes.
/// No wallet prompt, financial replay or inferred completion on network failure.
final refreshFundingActivityProvider = Provider<Future<void> Function()>((ref) {
  Future<void>? pending;
  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (auth.busy || auth.needsWalletConnection) return;
    final identity = auth.identity;
    bool current() => ref.mounted && ref.read(authProvider).identity == identity;
    final deposits = ref.read(pendingDepositSubmissionsProvider);
    for (final deposit in deposits.where((d) => d.hash != null)) {
      if (!current()) return;
      final controller = ref.read(depositSubmissionProvider.notifier);
      final state = ref.read(depositSubmissionProvider);
      if (state.step != DepositSubmissionStep.idle) continue;
      await controller.check(deposit.key, '');
      if (!current()) return;
      final checked = ref.read(depositSubmissionProvider);
      if (checked.receipt?.status == DepositReceiptStatus.succeeded &&
          ref.read(fundingSilentReadsProvider)) {
        await controller.checkCredit(deposit.key);
      }
    }
    if (!current() || !ref.read(fundingSilentReadsProvider)) return;
    final activity = ref.read(fundingActivityProvider);
    final account = ref.read(accountReadProvider);
    // A new local submission overrides a previous no-deposit read. Empty
    // accounts otherwise keep the existing silent no-deposit behavior.
    if (activity.pending.isEmpty &&
        deposits.isEmpty &&
        (account.failure?.requiresDeposit == true ||
            ref.read(transferHistoryProvider).failure?.requiresDeposit == true)) {
      return;
    }
    await ref.read(transferHistoryProvider.notifier).refresh();
  }

  return () {
    if (pending != null) return pending!;
    final task = refresh();
    pending = task;
    return task.whenComplete(() {
      if (identical(pending, task)) pending = null;
    });
  };
});

/// One initial discovery read, then polling only while a transfer is pending.
/// Route visibility, lifecycle and an active grant gate all silent history work.
final fundingActivityPollProvider = Provider.autoDispose.family<void, bool>((ref, visible) {
  if (!visible) return;
  ref.watch(fundingSilentReadsProvider);
  final identity = ref.watch(authProvider.select((s) => s.identity));
  final interval = ref.watch(fundingStatusPollIntervalProvider);
  var waitingForAccount = false;
  void poll({bool initial = false}) {
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    if (!ref.mounted ||
        identity == null ||
        lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    // Defer only automatic discovery. Explicit pull-to-refresh awaits its
    // own history request together with the account request in the batch.
    if (initial &&
        ref.read(fundingActivityProvider).pending.isEmpty &&
        ref.read(accountReadProvider).busy) {
      waitingForAccount = true;
      return;
    }
    waitingForAccount = false;
    final history = ref.read(transferHistoryProvider);
    if (initial &&
        history.account != null &&
        !history.stale &&
        history.failure == null &&
        DateTime.now().toUtc().difference(history.account!.receivedAt) < interval) {
      return;
    }
    if (!initial && ref.read(fundingActivityProvider).pending.isEmpty) return;
    unawaited(ref.read(refreshFundingActivityProvider)());
  }

  ref.listen(accountReadProvider.select((s) => s.busy), (_, busy) {
    if (waitingForAccount && !busy) scheduleMicrotask(() => poll(initial: true));
  });

  Timer? timer;
  void updateTimer() {
    if (ref.read(fundingActivityProvider).pending.isEmpty) {
      timer?.cancel();
      timer = null;
    } else {
      timer ??= Timer.periodic(interval, (_) => poll());
    }
  }

  ref.listen(fundingActivityProvider, (_, _) => updateTimer());
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    poll(initial: true);
    updateTimer();
  });
  ref.onDispose(() => timer?.cancel());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_approval_provider.dart';
import 'deposit_submission_provider.dart';
import 'deposit_wallet_provider.dart';

/// Chooses the explicit wallet review from a freshly read on-chain allowance.
/// Both controllers independently revalidate it during prepare and confirm.
final depositEntryProvider = NotifierProvider.autoDispose<DepositEntryController, bool>(
  DepositEntryController.new,
);

class DepositEntryReview {
  const DepositEntryReview({this.approval, this.deposit, this.failure});
  final DepositApprovalReview? approval;
  final DepositSubmissionReview? deposit;
  final AccountReadFailure? failure;
}

class DepositEntryController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<DepositEntryReview?> prepare(DepositWalletQuery query, String amount) async {
    if (state) return null;
    final identity = ref.read(authProvider).identity;
    if (identity?.walletAddress == null || ref.read(authProvider).busy) return null;
    state = true;
    bool current() => ref.mounted && ref.read(authProvider).identity == identity;
    try {
      await ref.read(depositWalletProvider(query).notifier).refresh();
      if (!current()) return null;
      final wallet = ref.read(depositWalletProvider(query));
      if (wallet.failure case final failure?) return DepositEntryReview(failure: failure);
      final check = checkDepositAmount(
        input: amount,
        query: query,
        snapshot: wallet.account,
        stale: wallet.stale,
      );
      if (check.errorKey case final key?) {
        return DepositEntryReview(failure: AccountReadFailure(key));
      }
      if (check.units == null) return null;
      if (check.allowanceSufficient == false) {
        final approval = await ref.read(depositApprovalProvider.notifier).prepare(query, amount);
        if (!current()) return null;
        final result = ref.read(depositApprovalProvider);
        return DepositEntryReview(
          approval: approval,
          failure: result.failure == null
              ? approval == null
                    ? const AccountReadFailure('depositTransactionBusy')
                    : null
              : AccountReadFailure(result.failure!, details: result.errorDetails),
        );
      }
      final deposit = await ref
          .read(depositSubmissionProvider.notifier)
          .prepare(query, amount, acknowledgeUnknownLimits: true);
      if (!current()) return null;
      final result = ref.read(depositSubmissionProvider);
      return DepositEntryReview(
        deposit: deposit,
        failure: result.failure == null
            ? deposit == null
                  ? const AccountReadFailure('depositTransactionBusy')
                  : null
            : AccountReadFailure(result.failure!, details: result.errorDetails),
      );
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

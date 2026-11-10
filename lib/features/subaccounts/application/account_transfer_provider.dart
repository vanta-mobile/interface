import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../../core/application/wallet_operation_provider.dart';
import '../../../core/errors/api_error_details.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/subaccount_management.dart';
import 'account_entries_provider.dart';
import 'subaccount_management_provider.dart';

class AccountTransferState {
  const AccountTransferState({
    this.busy = false,
    this.review,
    this.submitted,
    this.failure,
    this.details,
  });
  final bool busy;
  final SubaccountManagementReview? review;
  final WalletOperationRecord? submitted;
  final String? failure;
  final ApiErrorDetails? details;
}

final accountTransferProvider =
    NotifierProvider.autoDispose<AccountTransferController, AccountTransferState>(
      AccountTransferController.new,
    );

class AccountTransferController extends Notifier<AccountTransferState> {
  int _revision = 0;
  @override
  AccountTransferState build() {
    ref.watch(subaccountManagementRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.signingAvailable,
          s.identity?.walletKind,
          s.busy,
        ),
      ),
      (a, b) {
        if (a != b) {
          _revision++;
          state = const AccountTransferState();
        }
      },
    );
    ref.onDispose(() => _revision++);
    return const AccountTransferState();
  }

  void cancel() {
    _revision++;
    state = const AccountTransferState();
  }

  void _eligible(String target) {
    final auth = ref.read(authProvider), current = ref.read(activeAccountEntryProvider);
    final destination = ref
        .read(accountEntriesProvider)
        .where((e) => e.address.toLowerCase() == target.toLowerCase())
        .singleOrNull;
    if (auth.busy ||
        auth.identity?.walletKind != WalletKind.external ||
        auth.identity?.signingAvailable != true ||
        current == null ||
        destination == null ||
        current.address.toLowerCase() == target.toLowerCase()) {
      throw const AccountReadFailure('authWalletChanged');
    }
    if (ref.read(currentWalletOperationsProvider).any((r) => !r.acknowledged)) {
      throw const AccountReadFailure('walletOperationPending');
    }
    if (current.freezeRequested || destination.freezeRequested) {
      throw const AccountReadFailure('accountsFrozenNotice');
    }
  }

  Future<void> _balance(String asset, Decimal amount) async {
    await ref.read(accountReadProvider.notifier).refresh();
    final snapshot = ref.read(accountReadProvider);
    if (snapshot.failure != null) throw snapshot.failure!;
    if (snapshot.account == null || snapshot.stale || snapshot.busy) {
      throw const AccountReadFailure('accountsTransferBalanceNotice');
    }
    final available = snapshot.account!.assets
        .where((a) => a.asset == asset)
        .singleOrNull
        ?.availableBalance;
    if (available == null) throw const AccountReadFailure('accountsTransferBalanceNotice');
    if (amount > available) throw const AccountReadFailure('accountsTransferInsufficient');
  }

  Future<void> prepare({
    required String target,
    required String asset,
    required String amount,
  }) async {
    if (state.busy || state.review != null || state.submitted != null) return;
    final identity = ref.read(authProvider).identity;
    if (identity?.walletAddress == null) return;
    final revision = ++_revision;
    bool current() => ref.mounted && revision == _revision;
    state = const AccountTransferState(busy: true);
    try {
      _eligible(target);
      if (!RegExp(r'^(0|[1-9]\d*)(?:\.\d{1,18})?$').hasMatch(amount)) {
        throw const AccountReadFailure('subaccountInputInvalid');
      }
      final value = Decimal.parse(amount);
      if (value <= Decimal.zero) throw const AccountReadFailure('subaccountInputInvalid');
      await _balance(asset, value);
      if (!current()) return;
      _eligible(target);
      final review = await ref
          .read(subaccountManagementRepositoryProvider)
          .prepare(
            identity: identity!,
            kind: WalletOperationKind.subaccountTransfer,
            terms: {
              'from': identity.walletAddress!,
              'to': target,
              'asset': asset,
              'amount': amount,
              'direction': 'FUTURE_FUTURE',
            },
            isCurrent: current,
          );
      if (current()) state = AccountTransferState(review: review);
    } catch (e) {
      if (current()) {
        state = AccountTransferState(
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
          details: errorDetailsOf(e),
        );
      }
    }
  }

  Future<void> confirm(SubaccountManagementReview review) async {
    if (state.busy || !identical(state.review, review)) return;
    final revision = _revision;
    bool current() => ref.mounted && revision == _revision;
    state = AccountTransferState(busy: true, review: review);
    try {
      final terms = review.record.terms;
      _eligible(terms['to']!);
      await _balance(terms['asset']!, Decimal.parse(terms['amount']!));
      if (!current()) return;
      _eligible(terms['to']!);
      final record = await ref
          .read(subaccountManagementRepositoryProvider)
          .submit(review, isCurrent: current);
      if (current()) {
        ref.read(accountReadProvider.notifier).markStale();
        state = AccountTransferState(submitted: record);
      }
    } catch (e) {
      if (current()) {
        state = AccountTransferState(
          review: review,
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
          details: errorDetailsOf(e),
        );
      }
    }
  }
}

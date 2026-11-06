import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';
import 'funding_transaction_activity.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/deposit_submission_journal.dart';
import '../data/deposit_submission_receipt_repository.dart';
import '../data/deposit_approval_receipt_repository.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';
import 'funding_catalog_provider.dart';
import 'transfer_history_provider.dart';
import 'deposit_approval_provider.dart';
import '../data/deposit_rpc_service.dart';
import '../domain/deposit_approval.dart'
    show DepositApprovalReceipt, DepositReceiptStatus, validFundingHash;
import '../domain/deposit_submission.dart';
import '../domain/deposit_quote_validation.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_gas_provider.dart';

part 'deposit_submission_recovery.dart';

final depositSubmissionJournalProvider = Provider<DepositSubmissionJournal>((ref) {
  final journal = MemoryDepositSubmissionJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final depositSubmissionJournalSnapshotProvider =
    NotifierProvider<DepositSubmissionJournalController, DepositSubmissionJournalSnapshot>(
      DepositSubmissionJournalController.new,
    );

class DepositSubmissionJournalController extends Notifier<DepositSubmissionJournalSnapshot> {
  @override
  DepositSubmissionJournalSnapshot build() {
    final journal = ref.watch(depositSubmissionJournalProvider);
    final sub = journal.changes.listen((value) {
      if (ref.mounted) state = value;
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(depositSubmissionJournalProvider).reload();
    } catch (_) {
      /* Safe storage failure is published. */
    }
  }
}

final pendingDepositSubmissionsProvider = Provider<List<DepositSubmissionRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(depositSubmissionJournalSnapshotProvider)
      .records
      .where((r) => r.transaction.from.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});
final depositSubmissionReceiptRepositoryProvider = Provider<DepositSubmissionReceiptRepository>((
  ref,
) {
  final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RpcDepositSubmissionReceiptRepository(
    RpcDepositApprovalReceiptRepository(service, now: ref.watch(depositGasClockProvider)),
  );
});

class DepositSubmissionReview {
  const DepositSubmissionReview(
    this.identity,
    this.query,
    this.amount,
    this.quote,
    this.transaction,
  );
  final AuthIdentity identity;
  final DepositWalletQuery query;
  final String amount;
  final DepositGasQuote quote;
  final EvmWalletTransaction transaction;
}

enum DepositSubmissionStep { idle, preparing, reviewing, sending, checking }

class DepositSubmissionState {
  const DepositSubmissionState({
    this.step = DepositSubmissionStep.idle,
    this.review,
    this.record,
    this.receipt,
    this.credited = false,
    this.failure,
    this.errorDetails,
  });
  final DepositSubmissionStep step;
  final DepositSubmissionReview? review;
  final DepositSubmissionRecord? record;
  final bool credited;
  final DepositApprovalReceipt? receipt;
  final String? failure;
  final ApiErrorDetails? errorDetails;
  bool get busy =>
      step == DepositSubmissionStep.preparing ||
      step == DepositSubmissionStep.sending ||
      step == DepositSubmissionStep.checking;
}

final depositSubmissionProvider =
    NotifierProvider<DepositSubmissionController, DepositSubmissionState>(
      DepositSubmissionController.new,
    );

class DepositSubmissionController extends Notifier<DepositSubmissionState>
    with _DepositSubmissionRecovery {
  @override
  int _generation = 0;
  @override
  bool _working = false;
  @override
  DepositSubmissionState build() {
    ref.watch(depositSubmissionJournalProvider);
    ref.watch(depositApprovalJournalProvider);
    ref.watch(depositGasRepositoryProvider);
    ref.watch(depositSubmissionReceiptRepositoryProvider);
    ref.watch(fundingCatalogRepositoryProvider);
    ref.watch(transferHistoryRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
          s.busy,
        ),
      ),
      (a, b) {
        if (a != b) {
          _generation++;
          state = const DepositSubmissionState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const DepositSubmissionState();
  }

  @override
  bool _scope(AuthIdentity identity, int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(authProvider).identity?.id == identity.id &&
      ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
          identity.walletAddress?.toLowerCase();
  void _storageReady(DepositSubmissionJournal journal, String address) {
    final approvals = ref.read(depositApprovalJournalProvider).snapshot;
    if (!approvals.ready || approvals.failure != null) {
      throw const AccountReadFailure('depositApprovalStorage');
    }
    if (approvals.records.any((r) => r.transaction.from.toLowerCase() == address.toLowerCase())) {
      throw const AccountReadFailure('depositApprovalPending');
    }
    if (!journal.snapshot.ready || journal.snapshot.failure != null) {
      throw const AccountReadFailure('depositSubmissionStorage');
    }
    if (journal.snapshot.records.any(
      (r) => r.transaction.from.toLowerCase() == address.toLowerCase(),
    )) {
      throw const AccountReadFailure('depositSubmissionPending');
    }
  }

  @override
  String _failure(Object error) => switch (error) {
    AccountReadFailure(:final key) ||
    WalletTransactionNotSent(:final key) ||
    AuthFailure(:final key) => key,
    _ => 'depositRpcFailed',
  };
  Future<void> _catalog(DepositWalletQuery query, bool Function() current) async {
    final catalog = await ref
        .read(fundingCatalogRepositoryProvider)
        .read(FundingCatalogQuery(query.market, FundingOperation.deposit));
    if (!current()) throw const AccountReadFailure('authWalletChanged');
    final a = query.asset;
    if (!catalog.assets.any(
      (v) =>
          v.asset == a.asset &&
          v.chainId == a.chainId &&
          v.tokenAddress.toLowerCase() == a.tokenAddress.toLowerCase() &&
          v.decimals == a.decimals &&
          v.isNative == a.isNative &&
          v.routeType == a.routeType &&
          v.minimumDeposit == a.minimumDeposit,
    )) {
      throw const AccountReadFailure('withdrawalAssetChanged');
    }
  }

  Future<DepositSubmissionReview?> prepare(
    DepositWalletQuery query,
    String amount, {
    required bool acknowledgeUnknownLimits,
  }) async {
    if (!acknowledgeUnknownLimits) {
      state = const DepositSubmissionState(failure: 'depositLimitsAcknowledgement');
      return null;
    }
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return null;
    if (!identity!.signingAvailable) {
      state = const DepositSubmissionState(failure: 'authWalletReconnect');
      return null;
    }
    final generation = ++_generation;
    bool current() => _scope(identity, generation);
    _working = true;
    state = const DepositSubmissionState(step: DepositSubmissionStep.preparing);
    try {
      _storageReady(ref.read(depositSubmissionJournalProvider), identity.walletAddress!);
      await _catalog(query, current);
      if (!current()) return null;
      final quote = await ref
          .read(depositGasRepositoryProvider)
          .estimate(
            address: identity.walletAddress!,
            query: query,
            amount: amount,
            isCurrent: current,
          );
      if (!current()) return null;
      final tx = validatedDepositQuote(
        quote: quote,
        address: identity.walletAddress!,
        query: query,
        amount: amount,
        now: ref.read(depositGasClockProvider)().toUtc(),
      );
      if (quote.transaction.kind != DepositTransactionKind.deposit) {
        throw const AccountReadFailure('depositSubmissionApprovalNeeded');
      }
      final review = DepositSubmissionReview(identity, query, amount, quote, tx);
      state = DepositSubmissionState(step: DepositSubmissionStep.reviewing, review: review);
      return review;
    } catch (error) {
      if (current()) {
        state = DepositSubmissionState(
          failure: _failure(error),
          errorDetails: errorDetailsOf(error),
        );
      }
      return null;
    } finally {
      _working = false;
    }
  }

  void cancel(DepositSubmissionReview review) {
    if (!_working && identical(state.review, review)) {
      _generation++;
      state = const DepositSubmissionState();
    }
  }

  void stop() {
    _generation++;
    if (ref.mounted) state = const DepositSubmissionState();
  }

  Future<void> confirm(DepositSubmissionReview review) async {
    if (_working ||
        !identical(state.review, review) ||
        state.step != DepositSubmissionStep.reviewing) {
      return;
    }
    final activity = ref.read(fundingTransactionActivityProvider), owner = Object();
    if (!activity.acquire(owner)) {
      state = const DepositSubmissionState(failure: 'depositTransactionBusy');
      return;
    }
    final generation = _generation;
    bool current() => _scope(review.identity, generation);
    final journal = ref.read(depositSubmissionJournalProvider),
        repository = ref.read(depositGasRepositoryProvider);
    final sender = ref.read(identityRepositoryProvider), clock = ref.read(depositGasClockProvider);
    DepositSubmissionRecord? record;
    var prepared = false, dispatched = false;
    _working = true;
    state = DepositSubmissionState(step: DepositSubmissionStep.preparing, review: review);
    try {
      if (!current()) throw const WalletTransactionNotSent('authWalletChanged');
      validatedDepositQuote(
        quote: review.quote,
        address: review.transaction.from,
        query: review.query,
        amount: review.amount,
        now: clock().toUtc(),
      );
      _storageReady(journal, review.transaction.from);
      await _catalog(review.query, current);
      if (!current()) return;
      final quote = await repository.estimate(
        address: review.transaction.from,
        query: review.query,
        amount: review.amount,
        isCurrent: current,
      );
      if (!current()) return;
      final tx = validatedDepositQuote(
        quote: quote,
        address: review.transaction.from,
        query: review.query,
        amount: review.amount,
        now: clock().toUtc(),
      );
      if (quote.transaction.kind != review.quote.transaction.kind ||
          !mapEquals(tx.parameters, review.transaction.parameters)) {
        state = const DepositSubmissionState(failure: 'depositSubmissionChanged');
        return;
      }
      record = DepositSubmissionRecord(
        query: review.query,
        kind: quote.transaction.kind,
        amountUnits: quote.transaction.amountUnits,
        transaction: tx,
        preparedAt: clock().toUtc(),
        baseBlock: quote.wallet.blockNumber,
        baseBlockHash: quote.wallet.blockHash,
      );
      await journal.prepare(record);
      prepared = true;
      if (!current()) throw const WalletTransactionNotSent('authWalletChanged');
      validatedDepositQuote(
        quote: quote,
        address: tx.from,
        query: review.query,
        amount: review.amount,
        now: clock().toUtc(),
      );
      state = DepositSubmissionState(step: DepositSubmissionStep.sending, record: record);
      dispatched = true;
      final result = await sender.sendWalletTransaction(transaction: tx, isCurrent: current);
      // Do not guard these durable writes on UI scope: original-wallet hashes
      // must survive logout, route exit and controller disposal after dispatch.
      if (result.hash case final hash?) {
        await journal.attachHash(record.key, hash);
      } else if (result.status == WalletTransactionStatus.rejected) {
        await journal.complete(record.key);
      }
      if (current()) {
        state = DepositSubmissionState(
          record: record,
          failure: switch (result.status) {
            WalletTransactionStatus.rejected => 'authWalletRejected',
            WalletTransactionStatus.unknown => 'depositSubmissionUnknown',
            _ => null,
          },
        );
      }
    } catch (error) {
      var failure = _failure(error);
      if (prepared && record != null && (!dispatched || error is WalletTransactionNotSent)) {
        try {
          await journal.complete(record.key);
        } catch (_) {
          failure = 'depositSubmissionStorage';
        }
      } else if (dispatched && error is! AccountReadFailure) {
        failure = 'depositSubmissionUnknown';
      }
      if (current()) {
        state = DepositSubmissionState(
          record: record,
          failure: failure,
          errorDetails: errorDetailsOf(error),
        );
      }
    } finally {
      _working = false;
      activity.release(owner);
    }
  }
}

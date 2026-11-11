import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';
import 'funding_transaction_activity.dart';
import 'deposit_submission_provider.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/deposit_approval_journal.dart';
import '../data/deposit_approval_receipt_repository.dart';
import '../data/deposit_rpc_service.dart';
import '../domain/deposit_approval.dart';
import '../domain/deposit_quote_validation.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_transaction_attempt.dart';
import 'deposit_gas_provider.dart';

final depositApprovalJournalProvider = Provider<DepositApprovalJournal>((ref) {
  final journal = MemoryDepositApprovalJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final depositApprovalJournalSnapshotProvider =
    NotifierProvider<DepositApprovalJournalController, DepositApprovalJournalSnapshot>(
      DepositApprovalJournalController.new,
    );

class DepositApprovalJournalController extends Notifier<DepositApprovalJournalSnapshot> {
  @override
  DepositApprovalJournalSnapshot build() {
    final journal = ref.watch(depositApprovalJournalProvider);
    final sub = journal.changes.listen((value) {
      if (ref.mounted) state = value;
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(depositApprovalJournalProvider).reload();
    } catch (_) {
      /* Safe storage failure is published. */
    }
  }
}

final pendingDepositApprovalsProvider = Provider<List<DepositApprovalRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(depositApprovalJournalSnapshotProvider)
      .records
      .where((r) => r.transaction.from.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});
final depositApprovalReceiptRepositoryProvider = Provider<DepositApprovalReceiptRepository>((ref) {
  final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RpcDepositApprovalReceiptRepository(service, now: ref.watch(depositGasClockProvider));
});

class DepositApprovalReview {
  const DepositApprovalReview(this.identity, this.query, this.amount, this.quote, this.transaction);
  final AuthIdentity identity;
  final DepositWalletQuery query;
  final String amount;
  final DepositGasQuote quote;
  final EvmWalletTransaction transaction;
}

enum DepositApprovalStep { idle, preparing, reviewing, sending, checking }

class DepositApprovalState {
  const DepositApprovalState({
    this.step = DepositApprovalStep.idle,
    this.review,
    this.record,
    this.receipt,
    this.failure,
    this.errorDetails,
  });
  final DepositApprovalStep step;
  final DepositApprovalReview? review;
  final DepositApprovalRecord? record;
  final DepositApprovalReceipt? receipt;
  final String? failure;
  final ApiErrorDetails? errorDetails;
  bool get busy =>
      step == DepositApprovalStep.preparing ||
      step == DepositApprovalStep.sending ||
      step == DepositApprovalStep.checking;
}

final depositApprovalProvider = NotifierProvider<DepositApprovalController, DepositApprovalState>(
  DepositApprovalController.new,
);

class DepositApprovalController extends Notifier<DepositApprovalState> {
  int _generation = 0;
  bool _working = false;
  @override
  DepositApprovalState build() {
    ref.watch(depositApprovalJournalProvider);
    ref.watch(depositSubmissionJournalProvider);
    ref.watch(depositGasRepositoryProvider);
    ref.watch(depositApprovalReceiptRepositoryProvider);
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
          _working = false;
          state = const DepositApprovalState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const DepositApprovalState();
  }

  bool _scope(AuthIdentity identity, int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(authProvider).identity?.id == identity.id &&
      ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
          identity.walletAddress?.toLowerCase();
  void _storageReady(DepositApprovalJournal journal) {
    final other = ref.read(depositSubmissionJournalProvider).snapshot;
    if (!other.ready || other.failure != null) {
      throw const AccountReadFailure('depositSubmissionStorage');
    }

    if (!journal.snapshot.ready || journal.snapshot.failure != null) {
      throw const AccountReadFailure('depositApprovalStorage');
    }
  }

  String _failure(Object error) => switch (error) {
    AccountReadFailure(:final key) ||
    WalletTransactionNotSent(:final key) ||
    AuthFailure(:final key) => key,
    _ => 'depositRpcFailed',
  };
  Future<DepositApprovalReview?> prepare(DepositWalletQuery query, String amount) async {
    if (state.step == DepositApprovalStep.checking) stop();
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return null;
    if (!identity!.signingAvailable) {
      state = const DepositApprovalState(failure: 'authWalletReconnect');
      return null;
    }
    final generation = ++_generation;
    bool current() => _scope(identity, generation);
    _working = true;
    state = const DepositApprovalState(step: DepositApprovalStep.preparing);
    try {
      _storageReady(ref.read(depositApprovalJournalProvider));
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
      if (quote.transaction.kind == DepositTransactionKind.deposit) {
        throw const AccountReadFailure('depositApprovalNotNeeded');
      }
      final review = DepositApprovalReview(identity, query, amount, quote, tx);
      state = DepositApprovalState(step: DepositApprovalStep.reviewing, review: review);
      return review;
    } catch (error) {
      if (current()) {
        state = DepositApprovalState(failure: _failure(error), errorDetails: errorDetailsOf(error));
      }
      return null;
    } finally {
      if (generation == _generation) _working = false;
    }
  }

  void cancel(DepositApprovalReview review) {
    if (!_working && identical(state.review, review)) {
      _generation++;
      state = const DepositApprovalState();
    }
  }

  void stop() {
    _generation++;
    _working = false;
    if (ref.mounted) state = const DepositApprovalState();
  }

  Future<void> confirm(DepositApprovalReview review) async {
    if (_working ||
        !identical(state.review, review) ||
        state.step != DepositApprovalStep.reviewing) {
      return;
    }
    final activity = ref.read(fundingTransactionActivityProvider), owner = Object();
    final generation = _generation;
    bool current() => _scope(review.identity, generation);
    if (!activity.acquire(owner, isCurrent: current)) {
      state = const DepositApprovalState(failure: 'depositTransactionBusy');
      return;
    }
    final journal = ref.read(depositApprovalJournalProvider),
        repository = ref.read(depositGasRepositoryProvider);
    final sender = ref.read(identityRepositoryProvider), clock = ref.read(depositGasClockProvider);
    DepositApprovalRecord? record;
    var prepared = false, dispatched = false;
    _working = true;
    state = DepositApprovalState(step: DepositApprovalStep.preparing, review: review);
    try {
      if (!current()) throw const WalletTransactionNotSent('authWalletChanged');
      validatedDepositQuote(
        quote: review.quote,
        address: review.transaction.from,
        query: review.query,
        amount: review.amount,
        now: clock().toUtc(),
      );
      _storageReady(journal);
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
        state = const DepositApprovalState(failure: 'depositApprovalChanged');
        return;
      }
      record = DepositApprovalRecord(
        query: review.query,
        kind: quote.transaction.kind,
        amountUnits: quote.transaction.amountUnits,
        transaction: tx,
        preparedAt: clock().toUtc(),
        baseBlock: quote.wallet.blockNumber,
        baseBlockHash: quote.wallet.blockHash,
        attemptId: newFundingTransactionAttempt(),
      );
      // Keep earlier unsigned attempts so late hashes remain correctly attributed.
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
      state = DepositApprovalState(step: DepositApprovalStep.sending, record: record);
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
        state = DepositApprovalState(
          record: record,
          failure: switch (result.status) {
            WalletTransactionStatus.rejected => 'authWalletRejected',
            WalletTransactionStatus.unknown => 'depositApprovalUnknown',
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
          failure = 'depositApprovalStorage';
        }
      } else if (dispatched && error is! AccountReadFailure) {
        failure = 'depositApprovalUnknown';
      }
      if (current()) {
        state = DepositApprovalState(
          record: record,
          failure: failure,
          errorDetails: errorDetailsOf(error),
        );
      }
    } finally {
      if (generation == _generation) _working = false;
      activity.release(owner);
    }
  }

  Future<void> check(String key, String candidate) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    final journal = ref.read(depositApprovalJournalProvider);
    if (!journal.snapshot.ready || journal.snapshot.failure != null) {
      state = const DepositApprovalState(failure: 'depositApprovalStorage');
      return;
    }
    final record = journal.snapshot.records
        .where(
          (r) =>
              r.key == key &&
              r.transaction.from.toLowerCase() == identity!.walletAddress!.toLowerCase(),
        )
        .singleOrNull;
    if (record == null) return;
    final chosenHash = candidate.trim().isEmpty ? record.hash ?? '' : candidate.trim();
    final generation = ++_generation;
    bool current() => _scope(identity!, generation);
    _working = true;
    state = DepositApprovalState(step: DepositApprovalStep.checking, record: record);
    try {
      final receipt = await ref
          .read(depositApprovalReceiptRepositoryProvider)
          .read(record, chosenHash, isCurrent: current);
      if (!current()) return;
      if (!validFundingHash(receipt.hash) ||
          (chosenHash).toLowerCase() != receipt.hash.toLowerCase() ||
          receipt.status != DepositReceiptStatus.pending &&
              ((receipt.status == DepositReceiptStatus.replaced) == receipt.matchesIntent ||
                  !receipt.bound ||
                  receipt.confirmations < 2 ||
                  receipt.blockNumber == null ||
                  receipt.blockNumber! < record.baseBlock)) {
        throw const AccountReadFailure('depositRpcInvalid');
      }
      if (receipt.bound && receipt.matchesIntent && record.hash == null) {
        await journal.attachHash(record.key, receipt.hash);
      }
      if (!current()) return;
      if (receipt.status != DepositReceiptStatus.pending) await journal.complete(record.key);
      if (current()) state = DepositApprovalState(record: record, receipt: receipt);
    } catch (error) {
      if (current()) {
        state = DepositApprovalState(
          record: record,
          failure: _failure(error),
          errorDetails: errorDetailsOf(error),
        );
      }
    } finally {
      if (generation == _generation) _working = false;
    }
  }
}

import 'dart:async';

import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/data/deposit_approval_journal.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/domain/deposit_quote_validation.dart';
import 'package:vanta/features/funding/domain/deposit_transaction.dart';

import 'deposit_gas.dart';
import 'deposit_wallet.dart';
import 'identity_repository.dart';

DepositGasQuote approvalQuote({DateTime? now, BigInt? nonce, bool reset = false}) {
  final query = depositQuery();
  return gasQuote(
    query: query,
    wallet: depositSnapshot(
      query: query,
      receivedAt: now,
      allowance: reset ? BigInt.one : BigInt.zero,
    ),
    receivedAt: now,
    nonce: nonce,
  );
}

DepositApprovalRecord approvalRecord({DateTime? now, String? hash, bool reset = false}) {
  final quote = approvalQuote(now: now, reset: reset);
  return DepositApprovalRecord(
    query: quote.wallet.query,
    kind: quote.transaction.kind,
    amountUnits: quote.transaction.amountUnits,
    transaction: validatedDepositQuote(
      quote: quote,
      address: quote.address,
      query: quote.wallet.query,
      amount: '1',
      now: now ?? DateTime.now().toUtc(),
    ),
    preparedAt: now ?? quote.receivedAt,
    baseBlock: quote.wallet.blockNumber,
    baseBlockHash: quote.wallet.blockHash,
    hash: hash,
  );
}

class ApprovalIdentityRepository extends TestIdentityRepository {
  final transactions = <EvmWalletTransaction>[];
  Completer<void>? transactionGate;
  Object? transactionFailure;
  WalletTransactionResult transactionResult = WalletTransactionResult.fromResponse('0x${'b' * 64}');
  Future<void> Function()? beforeSend;
  @override
  Future<WalletTransactionResult> sendWalletTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) throw const WalletTransactionNotSent('authWalletChanged');
    await beforeSend?.call();
    transactions.add(transaction);
    await transactionGate?.future;
    if (transactionFailure case final error?) throw error;
    return transactionResult;
  }
}

class TestApprovalReceiptRepository implements DepositApprovalReceiptRepository {
  final calls = <(DepositApprovalRecord, String)>[];
  Completer<void>? gate;
  Object? failure;
  DepositApprovalReceipt? result;
  @override
  Future<DepositApprovalReceipt> read(
    DepositApprovalRecord record,
    String hash, {
    required bool Function() isCurrent,
  }) async {
    calls.add((record, hash));
    await gate?.future;
    if (failure case final error?) throw error;
    return result ??
        DepositApprovalReceipt(hash: hash, bound: true, status: DepositReceiptStatus.pending);
  }
}

class GatedApprovalJournal extends MemoryDepositApprovalJournal {
  Completer<void>? gate;
  Object? prepareFailure, hashFailure, completeFailure;
  @override
  Future<void> prepare(DepositApprovalRecord record) async {
    await gate?.future;
    if (prepareFailure case final error?) throw error;
    await super.prepare(record);
  }

  @override
  Future<void> attachHash(String key, String hash) async {
    if (hashFailure case final error?) throw error;
    await super.attachHash(key, hash);
  }

  @override
  Future<void> complete(String key) async {
    if (completeFailure case final error?) throw error;
    await super.complete(key);
  }
}

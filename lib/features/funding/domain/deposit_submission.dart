import 'package:decimal/decimal.dart';

import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import 'deposit_transaction.dart';
import 'deposit_wallet.dart';
import 'deposit_approval.dart' show DepositApprovalReceipt;

/// Public unsigned recovery terms only. No signatures, keys or executable queue.
class DepositSubmissionRecord {
  DepositSubmissionRecord({
    required this.query,
    required this.kind,
    required this.amountUnits,
    required this.transaction,
    required this.preparedAt,
    required this.baseBlock,
    required this.baseBlockHash,
    this.hash,
  }) {
    final asset = query.asset;
    if (query.verifiedMinimumDeposit != null && query.verifiedMinimumDeposit! < Decimal.zero ||
        kind != DepositTransactionKind.deposit ||
        amountUnits <= BigInt.zero ||
        transaction.chainId != asset.chainId ||
        preparedAt.millisecondsSinceEpoch < 0 ||
        preparedAt.millisecondsSinceEpoch > 10413792000000 ||
        baseBlock < BigInt.zero ||
        baseBlock >= BigInt.one << 256 ||
        !validSubmissionHash(baseBlockHash) ||
        hash != null && !validSubmissionHash(hash!) ||
        !RegExp(r'^[A-Za-z0-9_.-]{1,40}$').hasMatch(asset.asset)) {
      throw const FormatException();
    }
    final expected = nextDepositTransaction(
      DepositWalletSnapshot(
        address: transaction.from,
        receivedAt: preparedAt,
        query: query,
        assetUnits: amountUnits,
        nativeUnits: BigInt.zero,
        allowanceUnits: asset.isNative ? null : amountUnits,
        blockNumber: baseBlock,
        blockHash: baseBlockHash,
        blockTime: preparedAt,
      ),
      amountUnits,
    );
    if (expected.kind != kind ||
        expected.to != transaction.to ||
        expected.data != transaction.data ||
        expected.value != transaction.value) {
      throw const FormatException();
    }
  }
  final DepositWalletQuery query;
  final DepositTransactionKind kind;
  final BigInt amountUnits, baseBlock;
  final EvmWalletTransaction transaction;
  final DateTime preparedAt;
  final String baseBlockHash;
  final String? hash;
  String get key => '${transaction.chainId}:${transaction.from.toLowerCase()}:${transaction.nonce}';
  DepositSubmissionRecord withHash(String value) {
    if (hash != null && hash!.toLowerCase() != value.toLowerCase()) throw const FormatException();
    return DepositSubmissionRecord(
      query: query,
      kind: kind,
      amountUnits: amountUnits,
      transaction: transaction,
      preparedAt: preparedAt,
      baseBlock: baseBlock,
      baseBlockHash: baseBlockHash,
      hash: value,
    );
  }
}

bool validSubmissionHash(String value) =>
    RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(value) &&
    BigInt.parse(value.substring(2), radix: 16) != BigInt.zero;

class DepositSubmissionJournalSnapshot {
  DepositSubmissionJournalSnapshot({
    Iterable<DepositSubmissionRecord> records = const [],
    this.ready = true,
    this.failure,
  }) : records = List.unmodifiable(records);
  final List<DepositSubmissionRecord> records;
  final bool ready;
  final AccountReadFailure? failure;
}

abstract interface class DepositSubmissionJournal {
  DepositSubmissionJournalSnapshot get snapshot;
  Stream<DepositSubmissionJournalSnapshot> get changes;
  Future<void> reload();
  Future<void> prepare(DepositSubmissionRecord record);
  Future<void> attachHash(String key, String hash);
  Future<void> complete(String key);
  Future<void> close();
}

abstract interface class DepositSubmissionReceiptRepository {
  Future<DepositApprovalReceipt> read(
    DepositSubmissionRecord record,
    String hash, {
    required bool Function() isCurrent,
  });
}

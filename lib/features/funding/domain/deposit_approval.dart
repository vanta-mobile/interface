import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import 'deposit_transaction.dart';
import 'deposit_wallet.dart';

/// Public unsigned recovery terms only. No signatures, keys or executable queue.
class DepositApprovalRecord {
  DepositApprovalRecord({
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
    if (asset.isNative ||
        kind == DepositTransactionKind.deposit ||
        amountUnits <= BigInt.zero ||
        kind == DepositTransactionKind.resetApproval && amountUnits <= BigInt.one ||
        transaction.chainId != asset.chainId ||
        preparedAt.millisecondsSinceEpoch < 0 ||
        preparedAt.millisecondsSinceEpoch > 10413792000000 ||
        baseBlock < BigInt.zero ||
        baseBlock >= BigInt.one << 256 ||
        !validFundingHash(baseBlockHash) ||
        hash != null && !validFundingHash(hash!) ||
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
        allowanceUnits: kind == DepositTransactionKind.approve ? BigInt.zero : BigInt.one,
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
  DepositApprovalRecord withHash(String value) {
    if (hash != null && hash!.toLowerCase() != value.toLowerCase()) throw const FormatException();
    return DepositApprovalRecord(
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

bool validFundingHash(String value) =>
    RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(value) &&
    BigInt.parse(value.substring(2), radix: 16) != BigInt.zero;

class DepositApprovalJournalSnapshot {
  DepositApprovalJournalSnapshot({
    Iterable<DepositApprovalRecord> records = const [],
    this.ready = true,
    this.failure,
  }) : records = List.unmodifiable(records);
  final List<DepositApprovalRecord> records;
  final bool ready;
  final AccountReadFailure? failure;
}

abstract interface class DepositApprovalJournal {
  DepositApprovalJournalSnapshot get snapshot;
  Stream<DepositApprovalJournalSnapshot> get changes;
  Future<void> reload();
  Future<void> prepare(DepositApprovalRecord record);
  Future<void> attachHash(String key, String hash);
  Future<void> complete(String key);
  Future<void> close();
}

enum DepositReceiptStatus { pending, succeeded, reverted, replaced }

class DepositApprovalReceipt {
  const DepositApprovalReceipt({
    required this.hash,
    required this.bound,
    required this.status,
    this.confirmations = 0,
    this.gasFee,
    this.blockNumber,
    this.matchesIntent = true,
  });
  final String hash;
  final bool bound;
  final bool matchesIntent;
  final DepositReceiptStatus status;
  final int confirmations;
  final BigInt? gasFee, blockNumber;
}

abstract interface class DepositApprovalReceiptRepository {
  Future<DepositApprovalReceipt> read(
    DepositApprovalRecord record,
    String hash, {
    required bool Function() isCurrent,
  });
}

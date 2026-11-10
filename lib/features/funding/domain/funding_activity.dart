import 'package:decimal/decimal.dart';

import '../../../core/domain/wallet_operation.dart';
import 'deposit_submission.dart';
import 'deposit_wallet.dart';
import 'transfer_history.dart';

/// Owner-scoped progress; a submitted request is never a completion.
class FundingActivity {
  const FundingActivity({
    required this.key,
    required this.type,
    required this.amount,
    required this.asset,
    required this.startedAt,
    this.transfer,
    this.deposit,
    this.withdrawal,
  });
  factory FundingActivity.fromTransfer(TransferRecord r) => FundingActivity(
    key: 'history:${r.key}',
    type: r.type,
    amount: r.amount,
    asset: r.asset,
    startedAt: r.recordTime,
    transfer: r,
  );
  factory FundingActivity.fromDeposit(DepositSubmissionRecord r) => FundingActivity(
    key: 'deposit:${r.key}',
    type: TransferType.deposit,
    amount: depositQuantity(r.amountUnits, r.query.asset.decimals),
    asset: r.query.asset.asset,
    startedAt: r.preparedAt,
    deposit: r,
  );
  factory FundingActivity.fromWithdrawal(WalletOperationRecord r) => FundingActivity(
    key: 'withdrawal:${r.key}',
    type: TransferType.withdraw,
    amount: Decimal.parse(r.terms['amount']!),
    asset: r.terms['asset']!,
    startedAt: r.preparedAt,
    withdrawal: r,
  );
  final String key, asset;
  final TransferType type;
  final Decimal amount;
  final DateTime startedAt;
  final TransferRecord? transfer;
  final DepositSubmissionRecord? deposit;
  final WalletOperationRecord? withdrawal;
}

class FundingCompletion {
  const FundingCompletion(this.activity, this.status);
  final FundingActivity activity;
  final TransferStatus status;
}

class FundingActivityState {
  FundingActivityState({
    Iterable<FundingActivity> pending = const [],
    Iterable<FundingCompletion> completions = const [],
  }) : pending = List.unmodifiable(pending),
       completions = List.unmodifiable(completions);
  final List<FundingActivity> pending;
  final List<FundingCompletion> completions;
}

/// The exact hash, owner, market, chain, asset and quantity bind a local deposit.
/// An absent history record or a similar balance movement proves nothing.
TransferRecord? reconcileDeposit(DepositSubmissionRecord deposit, TransferHistory history) {
  if (deposit.hash == null ||
      history.address.toLowerCase() != deposit.transaction.from.toLowerCase() ||
      history.receivedAt.isBefore(deposit.preparedAt)) {
    return null;
  }
  final matches = history.records.where(
    (r) =>
        r.type == TransferType.deposit &&
        r.market == deposit.query.market &&
        r.chainId == deposit.query.asset.chainId &&
        r.asset == deposit.query.asset.asset &&
        r.txHash?.toLowerCase() == deposit.hash!.toLowerCase() &&
        r.amount == depositQuantity(deposit.amountUnits, deposit.query.asset.decimals),
  );
  return matches.length == 1 ? matches.single : null;
}

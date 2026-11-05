import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import 'deposit_transaction.dart';
import 'deposit_wallet.dart';

EvmWalletTransaction validatedDepositQuote({
  required DepositGasQuote quote,
  required String address,
  required DepositWalletQuery query,
  required String amount,
  required DateTime now,
}) {
  final check = checkDepositAmount(
    input: amount,
    query: query,
    snapshot: quote.wallet,
    stale: false,
  );
  if (quote.address.toLowerCase() != address.toLowerCase() ||
      quote.wallet.query != query ||
      quote.transaction.query != query ||
      check.errorKey != null ||
      check.units == null ||
      check.units != quote.transaction.amountUnits ||
      quote.wallet.receivedAt.isAfter(quote.receivedAt) ||
      quote.estimatedGas <= BigInt.zero ||
      quote.gasLimit !=
          (quote.estimatedGas * BigInt.from(120) + BigInt.from(99)) ~/ BigInt.from(100) ||
      quote.nativeRequired > quote.wallet.nativeUnits) {
    throw const AccountReadFailure('depositRpcInvalid');
  }
  final expected = nextDepositTransaction(quote.wallet, check.units!), actual = quote.transaction;
  if (actual.kind != expected.kind ||
      actual.from != expected.from ||
      actual.to != expected.to ||
      actual.data != expected.data ||
      actual.value != expected.value) {
    throw const AccountReadFailure('depositRpcInvalid');
  }
  if (quote.receivedAt.isAfter(now) ||
      !depositQuoteDeadline(quote).isAfter(now) ||
      quote.wallet.blockTime.isAfter(now.add(const Duration(minutes: 2)))) {
    throw const AccountReadFailure('depositReadStale');
  }
  try {
    return EvmWalletTransaction(
      chainId: query.asset.chainId,
      from: actual.from,
      to: actual.to,
      data: actual.data,
      value: actual.value,
      gasLimit: quote.gasLimit,
      gasPrice: quote.gasPrice,
      nonce: quote.nonce,
    );
  } on WalletTransactionNotSent {
    throw const AccountReadFailure('depositRpcInvalid');
  }
}

DateTime depositQuoteDeadline(DepositGasQuote quote) => ([
  quote.receivedAt.add(const Duration(seconds: 30)),
  quote.wallet.receivedAt.add(const Duration(seconds: 30)),
  quote.wallet.blockTime.add(const Duration(minutes: 2)),
]..sort()).first;

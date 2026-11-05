import 'dart:async';

import 'package:vanta/features/funding/domain/deposit_transaction.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';

import 'deposit_wallet.dart';

DepositGasQuote gasQuote({
  required DepositWalletQuery query,
  String amount = '1',
  DepositWalletSnapshot? wallet,
  DepositTransaction? transaction,
  DateTime? receivedAt,
  BigInt? estimatedGas,
  BigInt? gasLimit,
  BigInt? gasPrice,
  BigInt? nonce,
}) {
  final snapshot = wallet ?? depositSnapshot(query: query, receivedAt: receivedAt);
  final units = checkDepositAmount(
    input: amount,
    query: query,
    snapshot: snapshot,
    stale: false,
  ).units!;
  return DepositGasQuote(
    wallet: snapshot,
    transaction: transaction ?? nextDepositTransaction(snapshot, units),
    estimatedGas: estimatedGas ?? BigInt.from(21001),
    gasLimit: gasLimit ?? BigInt.from(25202),
    gasPrice: gasPrice ?? BigInt.from(1000000000),
    nonce: nonce ?? BigInt.from(7),
    receivedAt: receivedAt ?? DateTime.now().toUtc(),
  );
}

class TestDepositGasRepository implements DepositGasRepository {
  final calls = <(String, DepositWalletQuery, String)>[];
  Completer<void>? gate;
  Object? failure;
  DepositGasQuote? result;
  bool Function()? isCurrent;
  @override
  Future<DepositGasQuote> estimate({
    required String address,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  }) async {
    calls.add((address, query, amount));
    this.isCurrent = isCurrent;
    await gate?.future;
    if (failure case final error?) throw error;
    return result ?? gasQuote(query: query, amount: amount);
  }
}

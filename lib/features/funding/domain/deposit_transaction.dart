import '../../portfolio/domain/account_snapshot.dart';
import 'deposit_wallet.dart';
import 'funding_catalog.dart';
import 'transfer_history.dart';

enum DepositTransactionKind { resetApproval, approve, deposit }

String _addressWord(String value) {
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value) ||
      BigInt.parse(value.substring(2), radix: 16) == BigInt.zero) {
    throw const AccountReadFailure('depositRpcInvalid');
  }
  return value.substring(2).toLowerCase().padLeft(64, '0');
}

String _word(BigInt value) {
  if (value < BigInt.zero || value >= BigInt.one << 256) {
    throw const AccountReadFailure('depositAmountInvalid');
  }
  return value.toRadixString(16).padLeft(64, '0');
}

String depositHex(BigInt value) => '0x${value.toRadixString(16)}';

/// Unsigned next step only. A quote cannot submit it or prove account credit.
class DepositTransaction {
  const DepositTransaction({
    required this.kind,
    required this.query,
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    required this.amountUnits,
  });
  final DepositTransactionKind kind;
  final DepositWalletQuery query;
  final String from, to, data;
  final BigInt value, amountUnits;
  Map<String, String> get call =>
      Map.unmodifiable({'from': from, 'to': to, 'data': data, 'value': depositHex(value)});
}

DepositTransaction nextDepositTransaction(DepositWalletSnapshot wallet, BigInt units) {
  final query = wallet.query,
      asset = query.asset,
      vault = depositVaults[wallet.query.asset.chainId];
  if (vault == null ||
      asset.routeType != 'normal' ||
      asset.decimals < 0 ||
      asset.decimals > 255 ||
      asset.isNative && asset.decimals != 18 ||
      asset.isNative != (asset.tokenAddress.toLowerCase() == fundingNativePlaceholder)) {
    throw const AccountReadFailure('depositGasRouteUnsupported');
  }
  final owner = _addressWord(wallet.address), token = _addressWord(asset.tokenAddress);
  final spender = _addressWord(vault), amount = _word(units);
  if (units <= BigInt.zero) {
    throw const AccountReadFailure('depositAmountInvalid');
  }
  if (units > wallet.assetUnits) {
    throw const AccountReadFailure('depositBalanceInsufficient');
  }
  if (!asset.isNative &&
      (wallet.allowanceUnits == null ||
          wallet.allowanceUnits! < BigInt.zero ||
          wallet.allowanceUnits! >= BigInt.one << 256)) {
    throw const AccountReadFailure('depositRpcInvalid');
  }
  if (!asset.isNative && (wallet.allowanceUnits == null || wallet.allowanceUnits! < units)) {
    if (wallet.allowanceUnits == null) throw const AccountReadFailure('depositRpcInvalid');
    final reset = wallet.allowanceUnits! > BigInt.zero;
    return DepositTransaction(
      kind: reset ? DepositTransactionKind.resetApproval : DepositTransactionKind.approve,
      query: query,
      from: wallet.address,
      to: asset.tokenAddress,
      value: BigInt.zero,
      amountUnits: units,
      data: '0x095ea7b3$spender${reset ? _word(BigInt.zero) : amount}',
    );
  }
  // keccak256('depositFor(address,address,uint256,uint256)')[0:4].
  return DepositTransaction(
    kind: DepositTransactionKind.deposit,
    query: query,
    from: wallet.address,
    to: vault,
    value: asset.isNative ? units : BigInt.zero,
    amountUnits: units,
    data:
        '0xcf4a0c5e$token$owner$amount${_word(BigInt.from(query.market == TransferMarket.spot ? 1000 : 0))}',
  );
}

class DepositGasQuote implements WalletAccountSnapshot {
  const DepositGasQuote({
    required this.wallet,
    required this.transaction,
    required this.estimatedGas,
    required this.gasLimit,
    required this.gasPrice,
    required this.nonce,
    required this.receivedAt,
  });
  final DepositWalletSnapshot wallet;
  final DepositTransaction transaction;
  final BigInt estimatedGas, gasLimit, gasPrice, nonce;
  @override
  final DateTime receivedAt;
  @override
  String get address => wallet.address;
  BigInt get feeReserve => gasLimit * gasPrice;
  BigInt get nativeRequired => transaction.value + feeReserve;
}

abstract interface class DepositGasRepository {
  Future<DepositGasQuote> estimate({
    required String address,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  });
}

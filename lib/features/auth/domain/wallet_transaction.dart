/// A fully specified unsigned EVM call. BigInt values never cross a double.
final class EvmWalletTransaction {
  EvmWalletTransaction({
    required this.chainId,
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    required this.gasLimit,
    required this.gasPrice,
    required this.nonce,
  }) {
    bool address(String v) =>
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(v) &&
        BigInt.parse(v.substring(2), radix: 16) != BigInt.zero;
    if (!const [1, 56, 42161].contains(chainId) ||
        !address(from) ||
        !address(to) ||
        data.length > 131074 ||
        !RegExp(r'^0x(?:[a-fA-F0-9]{2})*$').hasMatch(data) ||
        value < BigInt.zero ||
        value >= BigInt.one << 256 ||
        gasPrice <= BigInt.zero ||
        gasPrice >= BigInt.one << 256 ||
        gasLimit <= BigInt.zero ||
        gasLimit >= BigInt.one << 64 ||
        nonce < BigInt.zero ||
        nonce >= (BigInt.one << 64) - BigInt.one) {
      throw const WalletTransactionNotSent('walletTransactionInvalid');
    }
  }
  final int chainId;
  final String from, to, data;
  final BigInt value, gasLimit, gasPrice, nonce;
  Map<String, String> get parameters => Map.unmodifiable({
    'chainId': '0x${chainId.toRadixString(16)}',
    'from': from,
    'to': to,
    'data': data,
    'value': '0x${value.toRadixString(16)}',
    'gas': '0x${gasLimit.toRadixString(16)}',
    'gasPrice': '0x${gasPrice.toRadixString(16)}',
    'nonce': '0x${nonce.toRadixString(16)}',
  });
}

/// Only raised before a wallet send request. Never use this for ambiguous RPC
/// errors after dispatch, which could otherwise invite a duplicate transfer.
final class WalletTransactionNotSent implements Exception {
  const WalletTransactionNotSent(this.key);
  final String key;
}

enum WalletTransactionStatus { hashReported, rejected, unknown }

final class WalletTransactionResult {
  const WalletTransactionResult.rejected() : status = WalletTransactionStatus.rejected, hash = null;
  const WalletTransactionResult.unknown() : status = WalletTransactionStatus.unknown, hash = null;
  const WalletTransactionResult._hash(this.hash) : status = WalletTransactionStatus.hashReported;
  factory WalletTransactionResult.fromResponse(Object? response) {
    if (response is String &&
        RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(response) &&
        BigInt.parse(response.substring(2), radix: 16) != BigInt.zero) {
      return WalletTransactionResult._hash(response);
    }
    return const WalletTransactionResult.unknown();
  }
  final WalletTransactionStatus status;
  final String? hash;
}

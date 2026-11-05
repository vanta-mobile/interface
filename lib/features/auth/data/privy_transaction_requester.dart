import 'package:flutter/services.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Same native transaction request as Privy 0.10.2's provider, preserving
/// structured PlatformException codes which its public wrapper discards.
/// Reference: rwa-interface/lib/data/auth/privy_transaction_requester.dart.
Future<Result<EthereumRpcResponse>> requestPrivyTransaction(
  EmbeddedEthereumWallet wallet,
  EthereumRpcRequest request,
) async {
  if (request.method != 'eth_sendTransaction' ||
      request.params.length != 1 ||
      request.params.single is! String) {
    throw const FormatException();
  }
  final response = await const MethodChannel('privy_flutter').invokeMapMethod<String, dynamic>(
    'ethSendRpcRequest',
    {...request.toJson(), 'walletAddress': wallet.address},
  );
  if (response == null || response['method'] != request.method || response['data'] is! String) {
    throw const FormatException();
  }
  return Success(EthereumRpcResponse.fromJson(response));
}

import 'dart:convert';

import 'package:privy_flutter/privy_flutter.dart';

import '../domain/auth_session.dart';

typedef PrivyTypedDataRequester = Future<Result<EthereumRpcResponse>> Function(
  EmbeddedEthereumWallet wallet,
  EthereumRpcRequest request,
);

Future<String> signEmbeddedPersonalMessage({
  required PrivyUser user,
  required String expectedAddress,
  required String message,
  required PrivyTypedDataRequester request,
}) async {
  final wallets = user.embeddedEthereumWallets
      .where((w) => w.address.toLowerCase() == expectedAddress.toLowerCase())
      .toList();
  if (wallets.length != 1) throw const AuthFailure('authWalletChanged');
  final bytes = utf8.encode(message).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final result = await request(
    wallets.single,
    EthereumRpcRequest.personalSign('0x$bytes', wallets.single.address),
  );
  return switch (result) {
    Success<EthereumRpcResponse>(:final value) => value.data,
    Failure<EthereumRpcResponse>() => throw const AuthFailure('authWalletUnavailable'),
  };
}

Future<String> signEmbeddedRequest({
  required PrivyUser user,
  required String expectedAddress,
  required Map<String, Object?> typedData,
  required PrivyTypedDataRequester request,
}) async {
  final wallets = user.embeddedEthereumWallets
      .where((wallet) => wallet.address.toLowerCase() == expectedAddress.toLowerCase())
      .toList();
  if (wallets.length != 1) throw const AuthFailure('authWalletChanged');
  final result = await request(
    wallets.single,
    EthereumRpcRequest.ethSignTypedDataV4(wallets.single.address, jsonEncode(typedData)),
  );
  final signature = switch (result) {
    Success<EthereumRpcResponse>(:final value) => value.data,
    Failure<EthereumRpcResponse>() => throw const AuthFailure('authWalletUnavailable'),
  };
  if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
    throw const AuthFailure('authWalletSignature');
  }
  return signature;
}

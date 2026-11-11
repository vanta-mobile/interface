import 'dart:convert';

import 'package:privy_flutter/privy_flutter.dart';

import '../domain/auth_session.dart';
import '../domain/wallet_connection.dart';
import '../domain/wallet_transaction.dart';
import 'privy_wallet_signer.dart';
import 'wallet_transaction_dispatch.dart';

/// Transaction-only adapter; the active caller owns its prompt lease.
/// Returned hashes belong to the original request even after a scope change.
class PrivyWalletTransactionSender {
  PrivyWalletTransactionSender(this._request);
  final PrivyTypedDataRequester _request;
  bool Function()? _pending;

  Future<WalletTransactionResult> send({
    required PrivyUser? user,
    required AuthIdentity? Function() resolveIdentity,
    required WalletConnection? connection,
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async {
    final AuthIdentity? identity;
    try {
      identity = resolveIdentity();
    } on AuthFailure catch (error) {
      throw WalletTransactionNotSent(error.key);
    }
    if (identity == null || !isCurrent()) {
      throw const WalletTransactionNotSent('authSessionUnavailable');
    }
    if (_pending?.call() ?? false) throw const WalletTransactionNotSent('walletTransactionBusy');
    if (identity.walletAddress?.toLowerCase() != transaction.from.toLowerCase()) {
      throw const WalletTransactionNotSent('authWalletChanged');
    }
    if (!identity.signingAvailable) {
      throw WalletTransactionNotSent(
        identity.walletKind == WalletKind.external
            ? 'authWalletReconnect'
            : 'authWalletUnavailable',
      );
    }
    final wallets = identity.walletKind == WalletKind.embedded
        ? (user?.embeddedEthereumWallets ?? <EmbeddedEthereumWallet>[])
              .where((wallet) => wallet.address.toLowerCase() == transaction.from.toLowerCase())
              .toList()
        : <EmbeddedEthereumWallet>[];
    if (identity.walletKind == WalletKind.external && connection == null ||
        identity.walletKind == WalletKind.embedded && wallets.length != 1) {
      throw const WalletTransactionNotSent('authWalletChanged');
    }
    if (!isCurrent()) throw const WalletTransactionNotSent('authWalletChanged');
    final owner = isCurrent;
    _pending = owner;
    try {
      if (identity.walletKind == WalletKind.external) {
        try {
          return await connection!.sendTransaction(transaction: transaction, isCurrent: isCurrent);
        } on WalletTransactionNotSent {
          rethrow;
        } catch (_) {
          return const WalletTransactionResult.unknown();
        }
      }
      return await dispatchWalletTransaction(() async {
        final result = await _request(
          wallets.single,
          EthereumRpcRequest.ethSendTransaction(jsonEncode(transaction.parameters)),
        );
        return switch (result) {
          Success<EthereumRpcResponse>(:final value) when value.method == 'eth_sendTransaction' =>
            value.data,
          _ => null,
        };
      });
    } finally {
      if (identical(_pending, owner)) _pending = null;
    }
  }
}

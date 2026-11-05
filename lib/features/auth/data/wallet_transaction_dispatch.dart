import 'dart:async';

import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart' show JsonRpcError;

import '../domain/wallet_transaction.dart';

/// Call only after all local preflight checks. No exception after this boundary
/// proves no broadcast, except a structured EIP-1193 user rejection (4001).
Future<WalletTransactionResult> dispatchWalletTransaction(Future<Object?> Function() request) {
  final result = Completer<WalletTransactionResult>();
  void fail(Object error, StackTrace _) {
    if (result.isCompleted) return;
    final rejected =
        error is PlatformException && error.code == '4001' ||
        error is JsonRpcError && error.code == 4001;
    result.complete(
      rejected ? const WalletTransactionResult.rejected() : const WalletTransactionResult.unknown(),
    );
  }

  // Reown may raise an async-void modal callback error separately from request.
  // Contain it here without printing raw errors or changing a returned hash.
  runZonedGuarded(() async {
    try {
      final response = await request();
      if (!result.isCompleted) result.complete(WalletTransactionResult.fromResponse(response));
    } catch (error, stack) {
      fail(error, stack);
    }
  }, fail);
  return result.future;
}

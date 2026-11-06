import 'wallet_transaction.dart';

/// A connected EOA owns its signing operations. No key material crosses here.
abstract interface class WalletConnection {
  String get address;
  String get chainId;

  /// Public display metadata from the connected wallet, never signer identity.
  String? get walletName;
  bool get isCurrent;
  Stream<void> get invalidations;
  Future<String> signPersonalMessage(String message);
  Future<String> signTypedData(Map<String, Object?> data);
  Future<WalletTransactionResult> sendTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  });

  /// Releases local observers without disconnecting a replacement connection.
  Future<void> release();
  Future<void> disconnect();
}

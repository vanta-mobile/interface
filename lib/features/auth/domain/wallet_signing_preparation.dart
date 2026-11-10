/// Optional capability for selecting an approved network before signing.
/// Preparation must finish before obtaining a short-lived financial nonce.
abstract interface class WalletSigningPreparation {
  Future<void> prepareSigning({
    required String expectedAddress,
    required int chainId,
    required bool Function() isCurrent,
  });
}

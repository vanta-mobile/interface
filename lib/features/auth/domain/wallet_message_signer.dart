/// Personal messages use the currently selected wallet, without creating one.
abstract interface class WalletMessageSigner {
  Future<String> signPersonalMessage({required String expectedAddress, required String message});
}

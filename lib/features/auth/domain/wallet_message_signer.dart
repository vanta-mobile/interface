/// Personal messages use the currently selected wallet, without creating one.
abstract interface class WalletMessageSigner {
  /// Chain used to route personal signatures for this address. Chain-bound
  /// messages (SIWE) must declare this value and discard a changed network.
  /// Embedded EIP-191 signing has no selected network and uses Ethereum (1).
  int personalSigningChainId({required String expectedAddress});

  Future<String> signPersonalMessage({required String expectedAddress, required String message});
}

/// Optional capability exposing the network a connected external wallet is
/// on. Null for embedded wallets or without a live connection.
abstract interface class WalletNetworkSource {
  int? get walletChainId;
}

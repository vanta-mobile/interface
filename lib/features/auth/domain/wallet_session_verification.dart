/// Optional SDK capability. Cached connection metadata alone is not proof that
/// the wallet peer can still answer; a signing request that finds the peer
/// unresponsive sets [needsReconnect]. Failure preserves the address for reconnect.
abstract interface class WalletSessionVerification {
  bool get needsReconnect;
}

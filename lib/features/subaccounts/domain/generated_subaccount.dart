import '../../auth/domain/wallet_connection.dart';

/// Public metadata only. Key material stays inside the device wallet store.
class GeneratedSubaccount {
  const GeneratedSubaccount({
    required this.owner,
    required this.address,
    required this.name,
    this.backedUp = false,
  });
  final String owner, address, name;
  final bool backedUp;
  GeneratedSubaccount saved() =>
      GeneratedSubaccount(owner: owner, address: address, name: name, backedUp: true);
}

abstract interface class SubaccountWalletStore {
  Future<List<GeneratedSubaccount>> list();
  Future<GeneratedSubaccount> generate({required String owner, required String name});
  Future<String> reveal(String address);
  Future<String> sign(String address, Map<String, Object?> typedData);
  Future<void> acknowledgeBackup(String address);

  /// Removes an unbacked key whose creation request was never dispatched.
  Future<void> discard(String address);
  WalletConnection connection(GeneratedSubaccount account);
}

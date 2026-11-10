import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_repository.dart';
import '../../portfolio/domain/aster_account.dart';
import '../domain/generated_subaccount.dart';

/// Reads a backed-up device wallet without replacing the active account.
abstract interface class SubaccountBalanceReader {
  Future<AsterAccount> read(GeneratedSubaccount wallet, bool Function() isCurrent);
}

class SubaccountBalanceRepository implements SubaccountBalanceReader {
  SubaccountBalanceRepository(this.service, this.store, this.nonces);
  final AsterAccountService service;
  final SubaccountWalletStore store;
  final AsterReadNonces nonces;

  @override
  Future<AsterAccount> read(GeneratedSubaccount wallet, bool Function() isCurrent) async {
    if (!wallet.backedUp) throw const AccountReadFailure('accountsBackupNotice');
    final connection = store.connection(wallet);
    try {
      return await SignedAccountRepository(service, ({
        required expectedAddress,
        required typedData,
      }) {
        if (!isCurrent() ||
            !connection.isCurrent ||
            expectedAddress.toLowerCase() != connection.address.toLowerCase()) {
          throw const AccountReadFailure('authWalletChanged');
        }
        return connection.signTypedData(typedData);
      }, nonces: nonces).read(address: wallet.address, isCurrent: isCurrent, onStep: (_) {});
    } finally {
      await connection.release();
    }
  }
}

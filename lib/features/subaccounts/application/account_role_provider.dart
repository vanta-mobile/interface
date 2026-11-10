import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/subaccount_directory.dart';

/// Only a successful master-scoped directory read establishes this role.
/// Failure/empty results never establish that the wallet is a child.
final verifiedMainAccountProvider = NotifierProvider<VerifiedMainAccount, String?>(
  VerifiedMainAccount.new,
);

class VerifiedMainAccount extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.signingAvailable),
      ),
    );
    return null;
  }

  void accept(SubaccountDirectory directory) {
    final address = ref.read(authProvider).identity?.walletAddress;
    if (directory.address.toLowerCase() == address?.toLowerCase() &&
        directory.accounts.where((a) => a.isParent).length == 1) {
      state = address;
    }
  }
}

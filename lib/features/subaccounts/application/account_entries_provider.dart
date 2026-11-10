import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/wallet_operation_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/account_entry.dart';
import 'account_role_provider.dart';

final accountEntriesProvider = Provider<List<AccountEntry>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  final records = ref.watch(walletOperationStorageProvider).records;
  final verifiedMain =
      address != null &&
      ref.watch(verifiedMainAccountProvider)?.toLowerCase() == address.toLowerCase();
  return address == null
      ? const []
      : knownAccountEntries(address, records, verifiedMain: verifiedMain);
});
final activeAccountEntryProvider = Provider<AccountEntry?>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(accountEntriesProvider)
      .where((a) => a.address.toLowerCase() == address?.toLowerCase())
      .firstOrNull;
});
final canManageAccountsProvider = Provider<bool>(
  (ref) =>
      ref.watch(authProvider.select((s) => s.identity?.walletKind)) == WalletKind.external &&
      ref.watch(activeAccountEntryProvider)?.main == true,
);

// An unclassified wallet may inspect the signed directory to establish its role.
// Only a verified main account may create or change subaccounts.
final canInspectAccountsProvider = Provider<bool>((ref) {
  final identity = ref.watch(authProvider).identity;
  final entry = ref.watch(activeAccountEntryProvider);
  return identity?.walletKind == WalletKind.external &&
      entry != null &&
      (entry.main || !entry.roleKnown);
});

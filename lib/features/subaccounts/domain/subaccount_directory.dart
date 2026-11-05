import '../../portfolio/domain/account_snapshot.dart';

/// The documented list contains IDs and names only. An ID is not a wallet
/// address, a signing grant, an active-account selection or a freeze status.
class AsterSubaccount {
  const AsterSubaccount({required this.accountId, required this.name, required this.isParent});
  final int accountId;
  final String name;
  final bool isParent;
}

class SubaccountDirectory implements WalletAccountSnapshot {
  SubaccountDirectory({
    required this.address,
    required this.receivedAt,
    required Iterable<AsterSubaccount> accounts,
  }) : accounts = List.unmodifiable(accounts);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<AsterSubaccount> accounts;
  int get childCount => accounts.where((account) => !account.isParent).length;
}

typedef SubaccountListRepository = WalletAccountRepository<SubaccountDirectory>;
typedef SubaccountListState = AccountSnapshotState<SubaccountDirectory>;

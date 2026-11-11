import '../../portfolio/domain/account_snapshot.dart';

/// The live list returns `address` and may omit the documented
/// `subAccountName`. An ID is not a signing grant, an active-account
/// selection or a freeze status.
class AsterSubaccount {
  const AsterSubaccount({
    required this.accountId,
    required this.name,
    required this.isParent,
    this.address,
  });
  final int accountId;
  final String name;
  final bool isParent;
  final String? address;
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

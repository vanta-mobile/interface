import '../../../core/domain/wallet_operation.dart';

class AccountEntry {
  const AccountEntry({
    required this.address,
    required this.owner,
    this.name = '',
    this.main = false,
    this.roleKnown = true,
    this.freezeRequested = false,
  });
  final String address, owner, name;
  final bool main, roleKnown, freezeRequested;
}

/// Only explicit public creation records establish an address relationship.
/// Names and numeric directory IDs are deliberately never used as a join key.
List<AccountEntry> knownAccountEntries(
  String current,
  Iterable<WalletOperationRecord> records, {
  bool verifiedMain = false,
}) {
  final created = records
      .where((r) => r.kind == WalletOperationKind.createSubaccount && r.acknowledged)
      .toList();
  final child = created
      .where((r) => r.terms['child']!.toLowerCase() == current.toLowerCase())
      .firstOrNull;
  final owner = child?.address ?? current;
  final knownMain =
      child != null ||
      verifiedMain ||
      created.any((r) => r.address.toLowerCase() == current.toLowerCase());
  final result = <AccountEntry>[
    AccountEntry(address: owner, owner: owner, main: knownMain, roleKnown: knownMain),
  ];
  final seen = {owner.toLowerCase()};
  for (final record in created.where((r) => r.address.toLowerCase() == owner.toLowerCase())) {
    final address = record.terms['child']!;
    if (!seen.add(address.toLowerCase())) continue;
    final updates =
        records
            .where(
              (r) =>
                  r.address.toLowerCase() == owner.toLowerCase() &&
                  r.terms['child']?.toLowerCase() == address.toLowerCase() &&
                  (r.kind == WalletOperationKind.freezeSubaccount ||
                      r.kind == WalletOperationKind.unfreezeSubaccount),
            )
            .toList()
          ..sort((a, b) => a.nonce.compareTo(b.nonce));
    result.add(
      AccountEntry(
        address: address,
        owner: owner,
        name: record.terms['name']!,
        freezeRequested:
            updates.isNotEmpty &&
            (updates.last.kind == WalletOperationKind.freezeSubaccount ||
                !updates.last.acknowledged),
      ),
    );
  }
  return List.unmodifiable(result);
}

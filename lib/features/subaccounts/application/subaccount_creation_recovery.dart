import '../../../core/domain/wallet_operation.dart';
import '../domain/generated_subaccount.dart';
import '../domain/subaccount_directory.dart';
import '../domain/subaccount_management.dart';

/// Reconciles unresolved creations of the directory owner against the signed
/// directory, the server's record of children. A listed child is reported as
/// created; an unlisted one past [creationSettleWindow] is cleared and its
/// unused, unbacked key discarded. Never sends or replays a write.
Future<bool> reconcileSubaccountCreations({
  required SubaccountDirectory directory,
  required WalletOperationJournal journal,
  required SubaccountWalletStore wallets,
}) async {
  final owner = directory.address.toLowerCase();
  final children = directory.accounts.where((a) => !a.isParent).toList();
  // Without an address on every child row, absence cannot be proven.
  final complete = children.every((a) => a.address != null);
  final listed = {for (final a in children) ?a.address?.toLowerCase()};
  var changed = false;
  for (final record in journal.snapshot.records.toList()) {
    if (record.acknowledged ||
        record.kind != WalletOperationKind.createSubaccount ||
        record.address.toLowerCase() != owner) {
      continue;
    }
    final child = record.terms['child']!;
    if (listed.contains(child.toLowerCase())) {
      await journal.report(record.key);
      changed = true;
    } else if (complete &&
        directory.receivedAt.difference(record.preparedAt) >= creationSettleWindow) {
      await journal.removeNotSent(record.key);
      await wallets.discard(child);
      changed = true;
    }
  }
  return changed;
}

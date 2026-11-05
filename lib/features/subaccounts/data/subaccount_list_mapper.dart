import '../domain/subaccount_directory.dart';

SubaccountDirectory mapSubaccountDirectory(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
}) {
  // A client resource bound, not the PRD's ten-child creation limit. Existing
  // server records over that limit must still be shown, never silently dropped.
  if (payload is! List || payload.length > 1000) throw const FormatException();
  final accounts = <AsterSubaccount>[];
  final ids = <int>{};
  var parents = 0;
  for (final raw in payload) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final id = raw['accountId'], name = raw['subAccountName'], parent = raw['parentAccount'];
    if (id is! int ||
        id <= 0 ||
        id > 9223372036854775807 ||
        !ids.add(id) ||
        name is! String ||
        name.length > 4096 ||
        parent is! bool) {
      throw const FormatException();
    }
    if (parent && ++parents > 1) throw const FormatException();
    accounts.add(AsterSubaccount(accountId: id, name: name, isParent: parent));
  }
  return SubaccountDirectory(address: address, receivedAt: receivedAt.toUtc(), accounts: accounts);
}

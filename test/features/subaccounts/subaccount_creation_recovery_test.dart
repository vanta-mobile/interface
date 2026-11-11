import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/subaccounts/application/subaccount_creation_recovery.dart';
import 'package:vanta/features/subaccounts/data/subaccount_wallet_store.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';

import '../../support/aster_account.dart';

void main() {
  final prepared = DateTime.utc(2026, 11, 11, 8);
  late MemoryWalletOperationJournal journal;
  late DeviceSubaccountWalletStore wallets;
  late String child;
  setUp(() async {
    final storage = <String, String>{};
    wallets = DeviceSubaccountWalletStore(
      read: (k) async => storage[k],
      write: (k, v) async => storage[k] = v,
    );
    child = (await wallets.generate(owner: accountAddress, name: 'Desk')).address;
    journal = MemoryWalletOperationJournal();
    await journal.prepare(
      WalletOperationRecord(
        kind: WalletOperationKind.createSubaccount,
        address: accountAddress,
        nonce: 1,
        preparedAt: prepared,
        terms: {'child': child, 'name': 'Desk'},
      ),
    );
  });
  tearDown(() => journal.close());

  SubaccountDirectory directory(Duration after, {String? listed, bool addressless = false}) =>
      SubaccountDirectory(
        address: accountAddress,
        receivedAt: prepared.add(after),
        accounts: [
          const AsterSubaccount(accountId: 1, name: '', isParent: true),
          if (listed != null)
            AsterSubaccount(accountId: 2, name: '', isParent: false, address: listed),
          if (addressless) const AsterSubaccount(accountId: 3, name: 'Old', isParent: false),
        ],
      );

  test('listed child confirms a pending creation and keeps its key', () async {
    final changed = await reconcileSubaccountCreations(
      directory: directory(const Duration(seconds: 5), listed: child),
      journal: journal,
      wallets: wallets,
    );
    expect(changed, true);
    expect(journal.snapshot.records.single.acknowledged, true);
    expect((await wallets.list()).single.address, child);
  });
  test('absent child after the settle window clears the record and unused key', () async {
    await reconcileSubaccountCreations(
      directory: directory(const Duration(minutes: 3)),
      journal: journal,
      wallets: wallets,
    );
    expect(journal.snapshot.records, isEmpty);
    expect(await wallets.list(), isEmpty);
  });
  test('absence is not proof inside the window or without child addresses', () async {
    for (final d in [
      directory(const Duration(seconds: 30)),
      directory(const Duration(minutes: 3), addressless: true),
    ]) {
      expect(
        await reconcileSubaccountCreations(directory: d, journal: journal, wallets: wallets),
        false,
      );
    }
    expect(journal.snapshot.records.single.acknowledged, false);
    expect((await wallets.list()).length, 1);
  });
}

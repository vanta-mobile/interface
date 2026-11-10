import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/application/account_balances_provider.dart';
import 'package:vanta/features/subaccounts/application/account_entries_provider.dart';
import 'package:vanta/features/subaccounts/application/account_role_provider.dart';
import 'package:vanta/features/subaccounts/domain/account_entry.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';
import 'package:vanta/features/subaccounts/presentation/account_management_screen.dart';

import '../../support/account_switch_authorization.dart';
import '../../support/aster_account.dart';
import '../../support/generated_accounts.dart';
import '../../support/identity_repository.dart';
import '../../support/wallet_connection.dart';

void main() {
  test('unrelated or empty records never identify the current wallet as main', () {
    for (final records in <List<WalletOperationRecord>>[
      [],
      [createdSubaccountRecord()],
    ]) {
      final entries = knownAccountEntries('0x4444444444444444444444444444444444444444', records);
      expect(entries.single.main, false);
      expect(entries.single.roleKnown, false);
    }
    final entries = knownAccountEntries(generatedChildAddress, [createdSubaccountRecord()]);
    expect(entries.where((e) => e.address == accountAddress).single.main, true);
    expect(entries.where((e) => e.address == generatedChildAddress).single.roleKnown, true);
    expect(entries.where((e) => e.address == generatedChildAddress).single.main, false);
  });

  testWidgets('unknown role becomes main only after its signed directory; logout clears it', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t);
    await f.mount(t, const AccountManagementScreen());
    expect(f.container.read(activeAccountEntryProvider)!.roleKnown, false);
    expect(f.container.read(canManageAccountsProvider), false);
    f.container
        .read(verifiedMainAccountProvider.notifier)
        .accept(
          SubaccountDirectory(
            address: generatedChildAddress,
            receivedAt: DateTime.now(),
            accounts: const [AsterSubaccount(accountId: 1, name: '', isParent: true)],
          ),
        );
    expect(f.container.read(canManageAccountsProvider), false);
    await tapAccountControl(t, 'subaccount-list-refresh');
    expect(f.container.read(activeAccountEntryProvider)!.main, true);
    expect(f.container.read(canManageAccountsProvider), true);
    f.identity.events.add(null);
    await t.pumpAndSettle();
    expect(f.container.read(verifiedMainAccountProvider), null);
    expect(f.container.read(accountEntriesProvider), isEmpty);
    await f.close(t);
  });

  testWidgets('known child has a disabled main-only withdrawal action', (t) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    f.identity.restored = const AuthIdentity(
      id: 'child',
      walletAddress: generatedChildAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    );
    await f.mount(t, const Scaffold(body: PortfolioPage()));
    final withdraw = find.byKey(const Key('portfolio-withdraw'));
    final action = t.widget<FilledButton>(
      find.descendant(of: withdraw, matching: find.byType(FilledButton)).first,
    );
    expect(action.onPressed, null);
    expect(find.text('Main account only'), findsOneWidget);
    expect(f.container.read(canInspectAccountsProvider), false);
    await f.close(t);
  });

  test('declined switch signature preserves identity and releases unused target', () async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final authorization = TestAccountSwitchAuthorization()..gate = Completer<void>();
    final target = TestWalletConnection(address: generatedChildAddress);
    final c = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        accountSwitchAuthorizationProvider.overrideWithValue(authorization),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(identity.dispose);
    addTearDown(target.dispose);
    c.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    final pending = c.read(authProvider.notifier).switchWithConnection(target);
    expect(c.read(authProvider).busy, true);
    expect(c.read(authProvider).identity?.walletAddress, accountAddress);
    expect(identity.externalLogins, 0);
    authorization.failure = const AuthFailure('authWalletCancelled');
    authorization.gate!.complete();
    await pending;
    expect(authorization.from, accountAddress);
    expect(authorization.to, generatedChildAddress);
    expect(c.read(authProvider).identity?.walletAddress, accountAddress);
    expect(c.read(authProvider).failure?.key, 'authWalletCancelled');
    expect(identity.externalLogins, 0);
    expect(target.isCurrent, false);
  });

  testWidgets('local balance refresh preserves data on failure, waits, and cancels on logout', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t);
    final wallet = await f.wallets.generate(owner: accountAddress, name: 'Local');
    await f.wallets.acknowledgeBackup(wallet.address);
    await f.journal.prepare(createdSubaccountRecord(address: wallet.address));
    await f.mount(t, const AccountManagementScreen());
    final key = wallet.address.toLowerCase();
    expect(f.balances.addresses, contains(wallet.address));
    expect(f.container.read(accountBalancesProvider).accounts[key], isNotNull);
    f.balances.gate = Completer<void>();
    f.balances.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
    var completed = false;
    final refresh = f.container
        .read(accountBalancesProvider.notifier)
        .refresh()
        .then((_) => completed = true);
    await t.pump();
    expect(completed, false);
    expect(f.container.read(accountBalancesProvider).accounts[key], isNotNull);
    f.balances.gate!.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(f.container.read(accountBalancesProvider).accounts[key], isNotNull);
    expect(f.container.read(accountBalancesProvider).failures[key]?.code, -2015);
    f.balances.failure = null;
    f.balances.gate = Completer<void>();
    final late = f.container.read(accountBalancesProvider.notifier).refresh();
    await t.pump();
    f.identity.events.add(null);
    await t.pump();
    expect(f.balances.latestCurrent!(), false);
    f.balances.gate!.complete();
    await late;
    await t.pumpAndSettle();
    expect(f.container.read(accountBalancesProvider).accounts, isEmpty);
    await f.close(t);
  });

  testWidgets('unbacked and unrelated device wallets never receive balance requests', (t) async {
    final f = GeneratedAccountsFixture(t);
    final unbacked = await f.wallets.generate(owner: accountAddress, name: 'Pending');
    await f.journal.prepare(createdSubaccountRecord(address: unbacked.address));
    final unrelated = await f.wallets.generate(owner: generatedChildAddress, name: 'Other');
    await f.wallets.acknowledgeBackup(unrelated.address);
    await f.mount(t, const AccountManagementScreen());
    expect(f.balances.addresses, isEmpty);
    await f.close(t);
  });
}

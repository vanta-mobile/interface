import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/presentation/account_management_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_list_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/generated_accounts.dart';

void main() {
  for (final spec in [
    (const Size(320, 844), 'zh'),
    (const Size(320, 844), 'en'),
    (const Size(844, 390), 'en'),
    (const Size(768, 1024), 'zh'),
  ]) {
    testWidgets('management explicit read and safe missing address fit $spec', (t) async {
      final f = GeneratedAccountsFixture(t);
      await f.mount(t, const AccountManagementScreen(), size: spec.$1, locale: spec.$2, scale: 1.5);
      expect(f.directory.calls, 0);
      await tapAccountControl(t, 'subaccount-list-refresh');
      expect(find.text('9007199254740993'), findsOneWidget);
      expect(find.text('交易台 / Desk A'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const Key('accounts-create-entry')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('accounts-create-entry')), findsOneWidget);
      f.directory.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
      await f.container.read(subaccountListProvider.notifier).refresh();
      await t.pumpAndSettle();
      expect(find.text('9007199254740993'), findsOneWidget);
      expect(find.textContaining('-2015'), findsOneWidget);
      expect(f.identity.wallets, 0);
      expect(t.takeException(), null);
      await f.close(t);
    });
  }
  testWidgets('public entry opens the designed screen without signing automatically', (t) async {
    final f = GeneratedAccountsFixture(t);
    await f.mount(
      t,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => openSubaccountList(context), child: const Text('open')),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(AccountManagementScreen), findsOneWidget);
    expect(f.directory.calls, 0);
    await f.close(t);
  });
  testWidgets('leaving the list cancels late reads and discards private state', (t) async {
    final f = GeneratedAccountsFixture(t);
    await f.mount(
      t,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => openSubaccountList(context), child: const Text('open')),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    f.directory.gate = Completer<void>();
    await t.tap(find.byKey(const Key('subaccount-list-refresh')));
    await t.pump();
    expect(f.container.read(subaccountListProvider).busy, true);
    Navigator.pop(t.element(find.byType(AccountManagementScreen)));
    await t.pumpAndSettle();
    f.directory.gate!.complete();
    await t.pumpAndSettle();
    expect(f.directory.sends, 0);
    expect(f.container.exists(subaccountListProvider), false);
    await f.close(t);
  });
  testWidgets('logout removes directory and all account addresses immediately', (t) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const AccountManagementScreen());
    await tapAccountControl(t, 'subaccount-list-refresh');
    f.identity.events.add(null);
    await t.pumpAndSettle();
    expect(f.container.read(authProvider).identity, null);
    expect(find.text('9007199254740993'), findsNothing);
    expect(find.text('Momentum'), findsNothing);
    final l = AppLocalizations.of(t.element(find.byType(AccountManagementScreen)));
    expect(find.text(l.subaccountMasterRequired), findsOneWidget);
    await f.close(t);
  });
}

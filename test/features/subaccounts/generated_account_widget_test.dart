import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/presentation/account_management_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_backup_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_details_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/generated_accounts.dart';

void main() {
  testWidgets('leaving creation during preflight retains the key and prevents a late POST', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t);
    await f.mount(t, const AccountManagementScreen());
    await tapAccountControl(t, 'subaccount-list-refresh');
    await tapAccountControl(t, 'accounts-create-entry');
    await t.enterText(find.byKey(const Key('generated-subaccount-name')), 'Desk');
    await tapAccountControl(t, 'generated-subaccount-create');
    f.repository.gate = Completer<void>();
    await t.ensureVisible(find.byKey(const Key('accounts-open-wallet')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('accounts-open-wallet')));
    await t.pump();
    expect((await f.wallets.list()).length, 1);
    await t.pumpWidget(UncontrolledProviderScope(container: f.container, child: const SizedBox()));
    await t.pumpAndSettle();
    expect(f.repository.latestCurrent!(), false);
    f.repository.gate!.complete();
    await t.pumpAndSettle();
    expect(f.repository.sends, 0);
    expect((await f.wallets.list()).length, 1);
    await f.close(t);
  });
  testWidgets('disposing a pending freeze sheet cancels its preflight', (t) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const SubaccountDetailsScreen(address: generatedChildAddress));
    await tapAccountControl(t, 'account-freeze-entry');
    await tapAccountControl(t, 'account-freeze-confirm');
    f.repository.gate = Completer<void>();
    await t.ensureVisible(find.byKey(const Key('accounts-open-wallet')));
    await t.tap(find.byKey(const Key('accounts-open-wallet')));
    await t.pump();
    await t.pumpWidget(UncontrolledProviderScope(container: f.container, child: const SizedBox()));
    await t.pumpAndSettle();
    expect(f.repository.latestCurrent!(), false);
    f.repository.gate!.complete();
    await t.pumpAndSettle();
    expect(f.repository.sends, 0);
    await f.close(t);
  });
  for (final language in ['en', 'zh']) {
    testWidgets('generate, hide on background, acknowledge backup, and manage target $language', (
      t,
    ) async {
      final f = GeneratedAccountsFixture(t);
      await f.mount(t, const AccountManagementScreen(), locale: language);
      await tapAccountControl(t, 'subaccount-list-refresh');
      await tapAccountControl(t, 'accounts-create-entry');
      await t.enterText(find.byKey(const Key('generated-subaccount-name')), 'Momentum');
      await tapAccountControl(t, 'generated-subaccount-create');
      expect(f.repository.sends, 0);
      await tapAccountControl(t, 'accounts-open-wallet');
      expect(find.byType(SubaccountBackupScreen), findsOneWidget);
      expect(find.byKey(const Key('subaccount-revealed-key')), findsNothing);
      expect(f.repository.sends, 1);
      final button = t.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('subaccount-backup-continue')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, null);
      await tapAccountControl(t, 'subaccount-reveal-key');
      expect(find.byKey(const Key('subaccount-revealed-key')), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byKey(const Key('subaccount-revealed-key')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      await tapAccountControl(t, 'subaccount-backup-saved');
      await tapAccountControl(t, 'subaccount-backup-continue');
      expect(find.byType(SubaccountDetailsScreen), findsNothing);
      expect(find.byType(AccountManagementScreen), findsOneWidget);
      final generated = (await f.wallets.list()).single;
      expect(generated.backedUp, true);
      await tapAccountControl(t, 'account-details-${generated.address}');
      expect(find.byType(SubaccountDetailsScreen), findsOneWidget);
      expect(f.container.read(authProvider).identity?.walletAddress, accountAddress);
      await tapAccountControl(t, 'account-freeze-entry');
      final l = AppLocalizations.of(t.element(find.byType(SubaccountDetailsScreen)));
      await t.tap(find.text(language == 'en' ? 'Cancel' : '取消').last);
      await t.pumpAndSettle();
      expect(f.repository.sends, 1);
      await tapAccountControl(t, 'account-freeze-entry');
      await tapAccountControl(t, 'account-freeze-confirm');
      await tapAccountControl(t, 'accounts-open-wallet');
      expect(f.journal.snapshot.records.last.kind, WalletOperationKind.freezeSubaccount);
      expect(find.text(l.accountsFrozenNotice), findsOneWidget);
      expect(f.container.read(authProvider).identity?.walletAddress, accountAddress);
      await tapAccountControl(t, 'account-details-primary');
      await tapAccountControl(t, 'account-freeze-confirm');
      await tapAccountControl(t, 'accounts-open-wallet');
      expect(f.journal.snapshot.records.last.kind, WalletOperationKind.unfreezeSubaccount);
      expect(t.takeException(), null);
      // Keep the list read provider observed until the original route is gone.
      expect(f.container.read(subaccountListProvider).account, isNotNull);
      await f.close(t);
    });
  }
}

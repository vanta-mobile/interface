import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/subaccounts/domain/account_entry.dart';
import 'package:vanta/features/subaccounts/domain/generated_subaccount.dart';
import 'package:vanta/features/subaccounts/presentation/account_management_screen.dart';
import 'package:vanta/features/subaccounts/presentation/account_selector_sheet.dart';
import 'package:vanta/features/subaccounts/presentation/account_switch_screen.dart';
import 'package:vanta/features/subaccounts/presentation/account_transfer_screen.dart';
import 'package:vanta/features/subaccounts/presentation/account_transfer_selection.dart';
import 'package:vanta/features/subaccounts/presentation/create_subaccount_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_backup_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_details_screen.dart';

import '../../support/aster_account.dart';
import '../../support/generated_accounts.dart';
import '../../support/wallet_connection.dart';

void main() {
  const child = AccountEntry(
    address: generatedChildAddress,
    owner: accountAddress,
    name: 'Momentum',
  );
  for (final language in ['en', 'zh']) {
    for (final size in [const Size(320, 700), const Size(844, 390), const Size(768, 1024)]) {
      for (final page in <String, Widget>{
        'details': const SubaccountDetailsScreen(address: generatedChildAddress),
        'switch': const AccountSwitchScreen(target: child),
        'transfer': const AccountTransferScreen(),
        'backup': const SubaccountBackupScreen(
          wallet: GeneratedSubaccount(
            owner: accountAddress,
            address: generatedChildAddress,
            name: 'Momentum',
          ),
          accepted: true,
        ),
      }.entries) {
        testWidgets('${page.key} fits $size $language enlarged text', (t) async {
          final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
          await f.mount(t, page.value, size: size, locale: language, scale: 1.5);
          await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
          await t.pumpAndSettle();
          expect(t.takeException(), null);
          await f.close(t);
        });
      }
    }
  }
  testWidgets('transfer review displays the exact 18-decimal amount and cancel preserves input', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const AccountTransferScreen());
    await tapAccountControl(t, 'accounts-transfer-refresh');
    await t.enterText(find.byKey(const Key('accounts-transfer-amount')), '1.000000000000000001');
    await tapAccountControl(t, 'accounts-transfer-submit');
    expect(find.text('1.000000000000000001'), findsOneWidget);
    expect(f.repository.sends, 0);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byKey(const Key('accounts-transfer-amount'))).controller!.text,
      '1.000000000000000001',
    );
    await f.close(t);
  });
  testWidgets('current account sheet only manages the master; selection does not silently switch', (
    t,
  ) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(
      t,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAccountSelector(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-subaccounts')), findsOneWidget);
    await tapAccountControl(t, 'account-choice-$generatedChildAddress');
    expect(find.byType(AccountSwitchScreen), findsOneWidget);
    expect(f.identity.externalLogins, 0);
    await f.close(t);
  });
  testWidgets('account selection disables the source and preserves the form', (t) async {
    final f = GeneratedAccountsFixture(t, records: [createdSubaccountRecord()]);
    await f.mount(t, const AccountTransferScreen());
    await tapAccountControl(t, 'accounts-transfer-refresh');
    await t.enterText(find.byKey(const Key('accounts-transfer-amount')), '1.25');
    FocusManager.instance.primaryFocus?.unfocus();
    await tapAccountControl(t, 'accounts-transfer-destination');
    expect(find.byType(AccountTransferSelection), findsOneWidget);
    final source = t.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('accounts-select-$accountAddress')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(source.onPressed, null);
    await tapAccountControl(t, 'accounts-select-$generatedChildAddress');
    expect(
      t.widget<TextField>(find.byKey(const Key('accounts-transfer-amount'))).controller!.text,
      '1.25',
    );
    expect(f.repository.sends, 0);
    await f.close(t);
  });
  testWidgets('freeze restriction returns to the form without dispatching a transfer', (t) async {
    final f = GeneratedAccountsFixture(
      t,
      records: [
        createdSubaccountRecord(),
        WalletOperationRecord(
          kind: WalletOperationKind.freezeSubaccount,
          address: accountAddress,
          nonce: 2,
          preparedAt: DateTime.utc(2026, 11, 9),
          terms: {'child': generatedChildAddress},
          acknowledged: true,
        ),
      ],
    );
    await f.mount(t, const AccountTransferScreen());
    await tapAccountControl(t, 'accounts-transfer-destination');
    await tapAccountControl(t, 'accounts-select-$generatedChildAddress');
    expect(find.byType(AccountTransferUnavailable), findsOneWidget);
    await t.tap(find.text('Back to transfer'));
    await t.pumpAndSettle();
    expect(find.byType(AccountTransferUnavailable), findsNothing);
    expect(find.byKey(const Key('accounts-transfer-amount')), findsOneWidget);
    expect(f.repository.sends, 0);
    await f.close(t);
  });
  testWidgets('declined switch retains identity and offers an explicit retry', (t) async {
    final connection = TestWalletConnection(address: generatedChildAddress);
    addTearDown(connection.dispose);
    final f = GeneratedAccountsFixture(
      t,
      records: [createdSubaccountRecord()],
      switchConnector: TestWalletConnector(connection),
    );
    f.identity.externalFailure = const AuthFailure(
      'authWalletCancelled',
      reason: 'Connection declined',
    );
    await f.mount(t, const AccountSwitchScreen(target: child));
    await tapAccountControl(t, 'account-switch-confirm');
    expect(find.text('Try switching again'), findsOneWidget);
    expect(find.textContaining('Connection declined'), findsOneWidget);
    expect(f.container.read(authProvider).identity?.walletAddress, accountAddress);
    expect(f.identity.externalLogins, 1);
    expect(f.identity.logouts, 0);
    // Retry is always a new explicit user action.
    connection.current = true;
    f.identity.externalFailure = null;
    await tapAccountControl(t, 'account-switch-confirm');
    expect(f.container.read(authProvider).identity?.walletAddress, generatedChildAddress);
    expect(f.identity.externalLogins, 2);
    await f.close(t);
  });
  for (final name in [
    'details',
    'switch',
    'list',
    'create',
    'backup',
    'freeze',
    'frozen',
    'transfer',
    'review',
    'submitted',
    'selector',
    'select',
    'restricted',
    'backup-saved',
    'switch-failed',
    'create-authorize',
    'freeze-authorize',
    'unfreeze-authorize',
  ]) {
    testWidgets('design screenshot $name', (t) async {
      final inter = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      final chinese = FontLoader('NotoSansSC')
        ..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'));
      await inter.load();
      await chinese.load();
      final connection = TestWalletConnection(address: generatedChildAddress);
      addTearDown(connection.dispose);
      final f = GeneratedAccountsFixture(
        t,
        switchConnector: TestWalletConnector(connection),
        records: [
          createdSubaccountRecord(),
          if (['frozen', 'restricted', 'unfreeze-authorize'].contains(name))
            WalletOperationRecord(
              kind: WalletOperationKind.freezeSubaccount,
              address: accountAddress,
              nonce: 2,
              preparedAt: DateTime.utc(2026, 11, 9),
              terms: {'child': generatedChildAddress},
              acknowledged: true,
            ),
        ],
      );
      final screen = switch (name) {
        'details' ||
        'frozen' ||
        'freeze' ||
        'freeze-authorize' ||
        'unfreeze-authorize' => const SubaccountDetailsScreen(address: generatedChildAddress),
        'switch' || 'switch-failed' => const AccountSwitchScreen(target: child),
        'list' || 'create' || 'create-authorize' => const AccountManagementScreen(),
        'backup' || 'backup-saved' => const SubaccountBackupScreen(
          wallet: GeneratedSubaccount(
            owner: accountAddress,
            address: generatedChildAddress,
            name: 'Momentum',
          ),
          accepted: true,
        ),
        'selector' => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAccountSelector(context),
              child: const Text('open'),
            ),
          ),
        ),
        _ => const AccountTransferScreen(),
      };
      const captureKey = Key('account-design-render');
      await f.mount(t, screen, safeInsets: const EdgeInsets.only(top: 59), captureKey: captureKey);
      if (['transfer', 'review', 'submitted', 'select', 'restricted'].contains(name)) {
        await tapAccountControl(t, 'accounts-transfer-refresh');
        await t.enterText(find.byKey(const Key('accounts-transfer-amount')), '10.00');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        if (['review', 'submitted', 'restricted'].contains(name)) {
          await tapAccountControl(t, 'accounts-transfer-submit');
        }
        if (name == 'select') await tapAccountControl(t, 'accounts-transfer-destination');
        if (name == 'submitted') await tapAccountControl(t, 'accounts-transfer-submit');
      }
      if (['list', 'create', 'create-authorize'].contains(name)) {
        await tapAccountControl(t, 'subaccount-list-refresh');
        if (name != 'list') {
          await tapAccountControl(t, 'accounts-create-entry');
          await t.enterText(find.byKey(const Key('generated-subaccount-name')), 'Momentum');
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
        }
      }
      if (name == 'create-authorize') await tapAccountControl(t, 'generated-subaccount-create');
      if (name == 'backup-saved') await tapAccountControl(t, 'subaccount-backup-saved');
      if (['freeze', 'freeze-authorize', 'unfreeze-authorize'].contains(name)) {
        await tapAccountControl(
          t,
          name == 'unfreeze-authorize' ? 'account-details-primary' : 'account-freeze-entry',
        );
        if (name != 'freeze') await tapAccountControl(t, 'account-freeze-confirm');
      }
      if (name == 'switch-failed') {
        f.identity.externalFailure = const AuthFailure('authWalletCancelled');
        await tapAccountControl(t, 'account-switch-confirm');
      }
      if (name == 'selector') {
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
      }
      await expectLater(find.byKey(captureKey), matchesGoldenFile('goldens/accounts-$name.png'));
      expect(t.takeException(), null);
      await f.close(t);
    });
  }
  testWidgets('creation fits a narrow keyboard window with enlarged Chinese text', (t) async {
    final f = GeneratedAccountsFixture(t);
    await f.mount(
      t,
      const AccountManagementScreen(),
      size: const Size(320, 390),
      locale: 'zh',
      scale: 1.5,
    );
    await tapAccountControl(t, 'subaccount-list-refresh');
    await tapAccountControl(t, 'accounts-create-entry');
    expect(find.byType(CreateSubaccountScreen), findsOneWidget);
    await t.enterText(find.byKey(const Key('generated-subaccount-name')), '策略');
    await t.drag(find.byType(CustomScrollView).last, const Offset(0, -500));
    await t.pumpAndSettle();
    expect(t.takeException(), null);
    await f.close(t);
  });
}

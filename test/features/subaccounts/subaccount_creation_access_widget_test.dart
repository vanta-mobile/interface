import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/subaccounts/application/subaccount_list_provider.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_list_screen.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_management_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/account_operations.dart';
import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/subaccounts.dart';

const _child = '0x3333333333333333333333333333333333333333';
AuthIdentity _identity(WalletKind kind) => AuthIdentity(
  id: signingIdentity.id,
  walletAddress: accountAddress,
  walletKind: kind,
  signingAvailable: true,
);

Future<void> _reveal(
  WidgetTester t,
  String key, {
  String page = 'subaccount-management-page',
}) async {
  final target = find.byKey(Key(key));
  final viewport = find
      .descendant(of: find.byKey(Key(page)), matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(viewport).position.jumpTo(0);
  await t.pump();
  await t.scrollUntilVisible(target, 160, scrollable: viewport);
  await Scrollable.ensureVisible(t.element(target), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key, {String page = 'subaccount-management-page'}) async {
  await _reveal(t, key, page: page);
  await t.tap(find.byKey(Key(key)).hitTestable());
  await t.pumpAndSettle();
}

void main() {
  late TestIdentityRepository auth;
  late TestSubaccountManagementRepository repo;
  late TestSubaccountListRepository directory;
  late ProviderContainer container;
  Future<void> mount(
    WidgetTester t,
    (double, double, String) spec, {
    WalletKind kind = WalletKind.embedded,
    bool list = false,
  }) async {
    auth = TestIdentityRepository()..restored = _identity(kind);
    repo = TestSubaccountManagementRepository();
    directory = TestSubaccountListRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(auth),
        subaccountManagementRepositoryProvider.overrideWithValue(repo),
        subaccountListRepositoryProvider.overrideWithValue(directory),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    t.view.physicalSize = Size(spec.$1, spec.$2);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(spec.$3),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: list ? const SubaccountListScreen() : const SubaccountManagementScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets(
      'Privy sees disabled creation with localized reason and working alternatives $spec',
      (t) async {
        await mount(t, spec);
        final l = AppLocalizations.of(t.element(find.byType(SubaccountManagementScreen)));
        expect(find.text(l.subaccountCreateExternalOnly), findsOneWidget);
        expect(find.byKey(const Key('subaccount-action-confirm')), findsNothing);
        await _reveal(t, 'subaccount-child-address');
        expect(
          t.widget<TextField>(find.byKey(const Key('subaccount-child-address'))).enabled,
          false,
        );
        await _reveal(t, 'subaccount-name');
        expect(t.widget<TextField>(find.byKey(const Key('subaccount-name'))).enabled, false);
        await _reveal(t, 'subaccount-action-prepare');
        expect(
          t.widget<FilledButton>(find.byKey(const Key('subaccount-action-prepare'))).onPressed,
          null,
        );
        await _reveal(t, 'subaccount-action');
        final dropdown = t.widget<DropdownButtonFormField<WalletOperationKind>>(
          find.byKey(const Key('subaccount-action')),
        );
        final items = t
            .widget<DropdownButton<WalletOperationKind>>(
              find.descendant(
                of: find.byKey(const Key('subaccount-action')),
                matching: find.byType(DropdownButton<WalletOperationKind>),
              ),
            )
            .items!;
        expect(
          items.singleWhere((i) => i.value == WalletOperationKind.createSubaccount).enabled,
          false,
        );
        expect(
          items
              .where((i) => i.value != WalletOperationKind.createSubaccount)
              .every((i) => i.enabled),
          true,
        );
        // Even a captured programmatic callback cannot select the disabled action.
        dropdown.onChanged!(WalletOperationKind.createSubaccount);
        await t.pumpAndSettle();
        expect(repo.prepares, 0);
        for (final kind in [
          WalletOperationKind.freezeSubaccount,
          WalletOperationKind.unfreezeSubaccount,
          WalletOperationKind.subaccountTransfer,
        ]) {
          await _tap(t, 'subaccount-action');
          final label = switch (kind) {
            WalletOperationKind.freezeSubaccount => l.subaccountFreeze,
            WalletOperationKind.unfreezeSubaccount => l.subaccountUnfreeze,
            _ => l.subaccountTransfer,
          };
          await t.tap(find.text(label).last);
          await t.pumpAndSettle();
          await _reveal(t, 'subaccount-child-address');
          expect(
            t.widget<TextField>(find.byKey(const Key('subaccount-child-address'))).enabled,
            true,
          );
          await t.enterText(find.byKey(const Key('subaccount-child-address')), _child);
          if (kind == WalletOperationKind.subaccountTransfer) {
            await _reveal(t, 'subaccount-transfer-amount');
            await t.enterText(find.byKey(const Key('subaccount-transfer-amount')), '1');
          }
          await _tap(t, 'subaccount-action-prepare');
          expect(container.read(subaccountManagementProvider).review!.record.kind, kind);
          await _tap(t, 'subaccount-action-confirm');
          expect(container.read(subaccountManagementProvider).result!.acknowledged, true);
        }
        expect(repo.prepares, 3);
        expect(repo.sends, 3);
        expect(auth.wallets, 0);
        expect(t.takeException(), null);
      },
    );
  }

  for (final locale in ['en', 'zh']) {
    testWidgets('EOA review and captured confirm expire on same-address Privy switch $locale', (
      t,
    ) async {
      await mount(t, (320, 844, locale), kind: WalletKind.external);
      expect(find.byKey(const Key('subaccount-create-restriction')), findsNothing);
      await _reveal(t, 'subaccount-child-address');
      await t.enterText(find.byKey(const Key('subaccount-child-address')), _child);
      await _reveal(t, 'subaccount-name');
      await t.enterText(find.byKey(const Key('subaccount-name')), 'Desk A');
      await _tap(t, 'subaccount-action-prepare');
      await _reveal(t, 'subaccount-child-signature');
      final signature = t
          .widget<TextField>(find.byKey(const Key('subaccount-child-signature')))
          .controller!;
      await t.enterText(
        find.byKey(const Key('subaccount-child-signature')),
        'fixture-secret-proof',
      );
      await _reveal(t, 'subaccount-action-confirm');
      final oldConfirm = t
          .widget<FilledButton>(find.byKey(const Key('subaccount-action-confirm')))
          .onPressed!;
      auth.events.add(_identity(WalletKind.embedded));
      await t.pumpAndSettle();
      expect(signature.text, isEmpty);
      expect(find.byKey(const Key('subaccount-action-confirm')), findsNothing);
      expect(find.byKey(const Key('subaccount-copy-child-challenge')), findsNothing);
      oldConfirm();
      await t.pumpAndSettle();
      expect(repo.sends, 0);
      // Switching remains independently usable while creation is disabled.
      await _reveal(t, 'subaccount-switch-address');
      expect(t.widget<TextField>(find.byKey(const Key('subaccount-switch-address'))).enabled, true);
      await t.enterText(find.byKey(const Key('subaccount-switch-address')), _child);
      await _tap(t, 'subaccount-switch-entered');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(_child)),
        findsOneWidget,
      );
      Navigator.of(t.element(find.byType(AlertDialog))).pop(false);
      await t.pumpAndSettle();
      auth.events.add(_identity(WalletKind.external));
      await t.pumpAndSettle();
      await _reveal(t, 'subaccount-child-address');
      expect(
        t.widget<TextField>(find.byKey(const Key('subaccount-child-address'))).controller!.text,
        isEmpty,
      );
      await _reveal(t, 'subaccount-name');
      expect(
        t.widget<TextField>(find.byKey(const Key('subaccount-name'))).controller!.text,
        isEmpty,
      );
      expect(find.byKey(const Key('subaccount-action-confirm')), findsNothing);
      oldConfirm();
      await t.pumpAndSettle();
      expect(repo.prepares, 1);
      expect(repo.sends, 0);
      expect(auth.wallets, 0);
      expect(t.takeException(), null);
    });

    testWidgets('Privy can explicitly read list and enter management $locale', (t) async {
      await mount(t, (320, 844, locale), list: true);
      expect(directory.calls, 0);
      await _tap(t, 'subaccount-list-refresh', page: 'subaccount-list-scroll');
      expect(directory.calls, 1);
      expect(directory.sends, 1);
      await _tap(t, 'subaccount-management-entry', page: 'subaccount-list-scroll');
      expect(find.byType(SubaccountManagementScreen), findsOneWidget);
      expect(find.byKey(const Key('subaccount-create-restriction')), findsOneWidget);
      expect(repo.prepares, 0);
      expect(auth.wallets, 0);
      expect(t.takeException(), null);
      await t.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await t.pump();
    });
  }
}

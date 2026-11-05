import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/presentation/trading_authorization_screen.dart';
import 'package:vanta/features/subaccounts/application/subaccount_management_provider.dart';
import 'package:vanta/features/subaccounts/presentation/subaccount_management_screen.dart';
import 'package:vanta/features/funding/application/withdrawal_provider.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/presentation/withdrawal_screen.dart';
import 'package:vanta/features/funding/presentation/deposit_submission_panel.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/account_operations.dart';
import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_approval.dart';
import '../../support/funding_info.dart';

Future<void> reveal(WidgetTester t, String key, String scroll) async {
  final target = find.byKey(Key(key));
  final viewport = find
      .descendant(of: find.byKey(Key(scroll)), matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(viewport).position.jumpTo(0);
  await t.pump();
  await t.scrollUntilVisible(target, 180, scrollable: viewport);
  await Scrollable.ensureVisible(t.element(target), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String key, String scroll) async {
  await reveal(t, key, scroll);
  await t.tap(find.byKey(Key(key)).hitTestable());
  await t.pumpAndSettle();
}

Future<void> mount(
  WidgetTester t,
  ProviderContainer c,
  Widget page,
  String locale,
  double width,
  double height,
) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('withdrawal grant is opt-in, displays normalized whitelist and clears at logout', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final c = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(
          TestTradingAuthorizationRepository(),
        ),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(identity.dispose);
    await mount(t, c, const TradingAuthorizationScreen(), 'zh', 320, 844);
    await tap(t, 'authorization-withdraw-toggle', 'authorization-page');
    await reveal(t, 'authorization-ip-whitelist', 'authorization-page');
    await t.enterText(find.byKey(const Key('authorization-ip-whitelist')), '203.0.113.8');
    await tap(t, 'authorization-prepare', 'authorization-page');
    expect(c.read(tradingAuthorizationProvider).review!.canWithdraw, true);
    await reveal(t, 'authorization-confirm', 'authorization-page');
    expect(find.text('203.0.113.8'), findsWidgets);
    identity.events.add(null);
    await t.pumpAndSettle();
    await reveal(t, 'authorization-withdraw-toggle', 'authorization-page');
    expect(
      t.widget<CheckboxListTile>(find.byKey(const Key('authorization-withdraw-toggle'))).value,
      false,
    );
    expect(find.byKey(const Key('authorization-ip-whitelist')), findsNothing);
    expect(t.takeException(), null);
  });
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('direct-wallet authorization review and partial permission evidence fits $spec', (
      t,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity,
          repo = TestTradingAuthorizationRepository();
      final c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          tradingAuthorizationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(identity.dispose);
      await mount(t, c, const TradingAuthorizationScreen(), spec.$3, spec.$1, spec.$2);
      expect(repo.sends, 0);
      expect(repo.checks, 0);
      await tap(t, 'authorization-prepare', 'authorization-page');
      expect(repo.sends, 0);
      await tap(t, 'authorization-confirm', 'authorization-page');
      expect(repo.sends, 1);
      await tap(t, 'authorization-check', 'authorization-page');
      expect(repo.checks, 1);
      final l = AppLocalizations.of(t.element(find.byType(TradingAuthorizationScreen)));
      await t.scrollUntilVisible(
        find.text(l.authorizationCannotTrade),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('authorization-page')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(l.authorizationCannotTrade), findsOneWidget);
      expect(t.takeException(), null);
      expect(identity.wallets, 0);
    });
    testWidgets(
      'subaccount child-address and signature inputs require separate review fits $spec',
      (t) async {
        final identity = TestIdentityRepository()..restored = signingIdentity,
            repo = TestSubaccountManagementRepository();
        final c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            subaccountManagementRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(c.dispose);
        addTearDown(identity.dispose);
        await mount(t, c, const SubaccountManagementScreen(), spec.$3, spec.$1, spec.$2);
        expect(repo.prepares, 0);
        await reveal(t, 'subaccount-child-address', 'subaccount-management-page');
        await t.enterText(
          find.byKey(const Key('subaccount-child-address')),
          '0x3333333333333333333333333333333333333333',
        );
        await reveal(t, 'subaccount-name', 'subaccount-management-page');
        await t.enterText(find.byKey(const Key('subaccount-name')), 'Desk A');
        await tap(t, 'subaccount-action-prepare', 'subaccount-management-page');
        expect(repo.prepares, 1);
        expect(repo.sends, 0);
        await reveal(t, 'subaccount-child-signature', 'subaccount-management-page');
        expect(
          t.widget<TextField>(find.byKey(const Key('subaccount-child-signature'))).obscureText,
          true,
        );
        await t.enterText(find.byKey(const Key('subaccount-child-signature')), '0x-fixture');
        await tap(t, 'subaccount-action-confirm', 'subaccount-management-page');
        expect(repo.sends, 1);
        expect(t.takeException(), null);
        expect(identity.wallets, 0);
      },
    );
    testWidgets('withdrawal displays fixed receiver and fee, confirms explicitly fits $spec', (
      t,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity,
          repo = TestWithdrawalRepository();
      final c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          withdrawalRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(identity.dispose);
      await mount(
        t,
        c,
        WithdrawalScreen(query: depositQuery(route: 'autoWithdraw')),
        spec.$3,
        spec.$1,
        spec.$2,
      );
      await reveal(t, 'withdrawal-amount', 'withdrawal-page');
      await t.enterText(find.byKey(const Key('withdrawal-amount')), '1');
      await tap(t, 'withdrawal-prepare', 'withdrawal-page');
      expect(repo.prepares, 1);
      expect(repo.sends, 0);
      expect(find.text(accountAddress), findsWidgets);
      await tap(t, 'withdrawal-confirm', 'withdrawal-page');
      expect(repo.sends, 1);
      expect(t.takeException(), null);
      expect(identity.wallets, 0);
    });
    testWidgets(
      'deposit acknowledges unknown caps then requires full transaction review fits $spec',
      (t) async {
        final now = DateTime.now().toUtc(),
            query = depositQuery(),
            identity = ApprovalIdentityRepository()..restored = signingIdentity;
        final gas = TestDepositGasRepository()..result = gasQuote(query: query, receivedAt: now),
            catalog = TestFundingCatalogRepository()
              ..rows = [fundingAssetRow()..['minDeposit'] = '0.1'];
        final c = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            depositGasRepositoryProvider.overrideWithValue(gas),
            depositGasClockProvider.overrideWithValue(() => now),
            fundingCatalogRepositoryProvider.overrideWithValue(catalog),
          ],
        );
        addTearDown(c.dispose);
        addTearDown(identity.dispose);
        await mount(
          t,
          c,
          Scaffold(
            body: ListView(
              key: const Key('deposit-widget-scroll'),
              children: [DepositSubmissionPanel(query: query, amount: '1', canPrepare: true)],
            ),
          ),
          spec.$3,
          spec.$1,
          spec.$2,
        );
        await reveal(t, 'deposit-submit-prepare', 'deposit-widget-scroll');
        expect(
          t.widget<FilledButton>(find.byKey(const Key('deposit-submit-prepare'))).onPressed,
          null,
        );
        await tap(t, 'deposit-limits-acknowledgement', 'deposit-widget-scroll');
        await tap(t, 'deposit-submit-prepare', 'deposit-widget-scroll');
        expect(find.byType(DepositSubmissionReviewScreen), findsOneWidget);
        expect(identity.transactions, isEmpty);
        await tap(t, 'deposit-submit-confirm', 'deposit-submit-review');
        expect(identity.transactions.length, 1);
        expect(t.takeException(), null);
        expect(identity.wallets, 0);
      },
    );
  }
}

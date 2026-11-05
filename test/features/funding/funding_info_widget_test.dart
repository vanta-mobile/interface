import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/application/withdraw_info_provider.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/funding_info_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/funding_info.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

Future<void> show(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(
        of: find.byKey(const Key('funding-info-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  // Expanded lazy children can correct the estimated scroll extent after the
  // first ensureVisible frame. Settle and reacquire the target after correction.
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.scrollUntilVisible(target, 150, scrollable: scroll);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) continue;
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) return;
  }
  fail('Scroll target disappeared after layout correction: $target');
}

Future<void> choose(WidgetTester tester, String key, String label) async {
  final dropdown = find.byKey(Key(key));
  await show(tester, dropdown);
  await tester.tap(dropdown.hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [(320.0, 844.0, 'zh'), (320.0, 844.0, 'en'), (844.0, 390.0, 'en')]) {
    testWidgets(
      'public configurations, explicit coin/USD limits, market/network changes and failure retention fit $spec',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        final catalogs = TestFundingCatalogRepository(), limits = TestWithdrawInfoRepository();
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: spec.$1,
          scale: 1.5,
          language: Locale(spec.$3),
          identityRepository: identity,
          fundingCatalogRepository: catalogs,
          withdrawInfoRepository: limits,
        );
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(tester, container);
        openFundingInfo(
          tester.element(find.byKey(const Key('account-button'))),
          TransferMarket.perp,
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(FundingInfoScreen)));
        expect(catalogs.calls, [
          const FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit),
        ]);
        expect(limits.calls, 0);
        await show(tester, find.byKey(const Key('funding-asset-56-USDT')));
        expect(find.text(l10n.fundingTokenContract), findsOneWidget);
        expect(
          find.text(fundingNativePlaceholder),
          findsNothing,
        ); // Native sentinel is never a deposit address.
        final withdraw = find.byKey(const Key('funding-operation-withdraw'));
        await show(tester, withdraw);
        await tester.tap(withdraw.hitTestable());
        await tester.pumpAndSettle();
        expect(
          catalogs.calls.last,
          const FundingCatalogQuery(TransferMarket.perp, FundingOperation.withdraw),
        );
        expect(limits.calls, 0);
        final read = find.byKey(const Key('withdraw-info-refresh'));
        await show(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        expect(limits.calls, 1);
        expect(container.read(withdrawInfoProvider).account, isNotNull);
        await show(tester, find.byKey(const Key('funding-asset-56-USDT')));
        expect(container.read(withdrawInfoProvider).account, isNotNull);
        expect(find.text('2.340000000000000002 USDT'), findsOneWidget);
        expect(find.text('23.400000000000000002 USDT'), findsOneWidget);
        expect(find.text('0.000000000000000001 USDT'), findsOneWidget);
        expect(find.text('9,000 USD'), findsWidgets);
        await choose(tester, 'funding-market', l10n.transferSpotMarket);
        await show(tester, find.byKey(const Key('funding-asset-56-USDT')));
        expect(find.text('1.230000000000000001 USDT'), findsOneWidget);
        expect(find.text('2.340000000000000002 USDT'), findsNothing);
        expect(limits.calls, 1); // The signed snapshot explicitly includes both markets.
        await choose(tester, 'funding-network', l10n.fundingEthereum);
        await show(tester, find.byKey(const Key('funding-asset-1-ETH')));
        expect(find.byKey(const Key('funding-asset-56-USDT')), findsNothing);
        expect(find.text('1.230000000000000001 USDT'), findsNothing);
        expect(find.text('—'), findsWidgets);
        await choose(tester, 'funding-network', l10n.fundingBnbChain);
        final search = find.byKey(const Key('funding-asset-search'));
        await show(tester, search);
        await tester.enterText(search, ' usdt ');
        await tester.pumpAndSettle();
        catalogs.failure = const FormatException();
        final refresh = find.byKey(const Key('funding-catalog-refresh'));
        await show(tester, refresh);
        await tester.tap(refresh.hitTestable());
        await tester.pumpAndSettle();
        expect(
          container
              .read(
                fundingCatalogProvider(
                  const FundingCatalogQuery(TransferMarket.spot, FundingOperation.withdraw),
                ),
              )
              .stale,
          true,
        );
        await show(tester, search);
        expect(tester.widget<TextField>(search).controller!.text, ' usdt ');
        expect(find.byKey(const Key('funding-asset-56-BNB')), findsNothing);
        catalogs.failure = null;
        await show(tester, refresh);
        await tester.tap(refresh.hitTestable());
        await tester.pumpAndSettle();
        limits.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
        await show(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        expect(container.read(withdrawInfoProvider).stale, true);
        await show(tester, find.byKey(const Key('funding-asset-56-USDT')));
        expect(find.text('1.230000000000000001 USDT'), findsOneWidget);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.text('1.230000000000000001 USDT'), findsNothing);
        expect(find.byKey(const Key('withdraw-info-address')), findsNothing);
        expect(identity.wallets, 0);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  for (final market in TransferMarket.values) {
    testWidgets('Portfolio $market entry opens the matching public configuration', (tester) async {
      final catalogs = TestFundingCatalogRepository();
      final container = setup(
        tester,
        language: const Locale('en'),
        fundingCatalogRepository: catalogs,
      );
      await launch(tester, container);
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      if (market == TransferMarket.spot) {
        await tester.tap(find.text('Spot'));
        await tester.pumpAndSettle();
      }
      final entry = find.byKey(const Key('funding-info-entry'));
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry.hitTestable());
      await tester.pumpAndSettle();
      expect(catalogs.calls.single.market, market);
      expect(find.byType(FundingInfoScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets(
    'signed-out users browse public assets, see empty configuration and must sign in for limits',
    (tester) async {
      final identity = TestIdentityRepository(),
          catalogs = TestFundingCatalogRepository()..rows = [];
      final limits = TestWithdrawInfoRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        fundingCatalogRepository: catalogs,
        withdrawInfoRepository: limits,
      );
      await launch(tester, container);
      openFundingInfo(tester.element(find.byKey(const Key('account-button'))), TransferMarket.spot);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(FundingInfoScreen)));
      await show(tester, find.text(l10n.fundingNoNetworkAssets));
      final withdraw = find.byKey(const Key('funding-operation-withdraw'));
      await show(tester, withdraw);
      await tester.tap(withdraw.hitTestable());
      await tester.pumpAndSettle();
      final read = find.byKey(const Key('withdraw-info-refresh'));
      await show(tester, read);
      await tester.tap(read.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(limits.calls, 0);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('stop waiting and route disposal invalidate a pending private signature', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final limits = TestWithdrawInfoRepository()..gate = Completer();
    addTearDown(identity.dispose);
    final container = setup(tester, identityRepository: identity, withdrawInfoRepository: limits);
    await launch(tester, container);
    openFundingInfo(tester.element(find.byKey(const Key('account-button'))), TransferMarket.perp);
    await tester.pumpAndSettle();
    final withdraw = find.byKey(const Key('funding-operation-withdraw'));
    await show(tester, withdraw);
    await tester.tap(withdraw.hitTestable());
    await tester.pumpAndSettle();
    final read = find.byKey(const Key('withdraw-info-refresh'));
    await show(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pump();
    final stop = find.byKey(const Key('withdraw-info-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    limits.gate!.complete();
    await tester.pumpAndSettle();
    expect(limits.sends, 0);
    limits.gate = Completer();
    await show(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pump();
    Navigator.of(tester.element(find.byType(FundingInfoScreen))).pop();
    await tester.pumpAndSettle();
    limits.gate!.complete();
    await tester.pumpAndSettle();
    expect(limits.sends, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

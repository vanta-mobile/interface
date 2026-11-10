import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_wallet_provider.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/deposit_wallet_screen.dart';
import 'package:vanta/features/funding/presentation/funding_info_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

class PublicReadIdentity extends TestIdentityRepository {
  int signatures = 0;
  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    signatures++;
    throw const AuthFailure('authWalletRejected');
  }
}

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  String scrollKey = 'deposit-wallet-scroll',
}) async {
  final scroll = find
      .descendant(of: find.byKey(Key(scrollKey)), matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.scrollUntilVisible(target, 150, scrollable: scroll);
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) continue;
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) return;
  }
  fail('Target disappeared after scroll correction: $target');
}

void open(WidgetTester tester, DepositWalletQuery query) =>
    Navigator.of(tester.element(find.byType(Navigator).first))
        .push<void>(MaterialPageRoute(builder: (_) => DepositWalletScreen(query: query)));

void main() {
  for (final spec in [(320.0, 844.0, 'en'), (320.0, 844.0, 'zh'), (844.0, 390.0, 'en')]) {
    testWidgets(
      'public balances, exact amount/allowance, Max, retention and wallet reset fit $spec',
      (tester) async {
        final identity = PublicReadIdentity()
          ..restored = const AuthIdentity(
            id: 'wallet',
            walletAddress: accountAddress,
            walletKind: WalletKind.external,
          );
        final repository = TestDepositWalletRepository(), query = depositQuery();
        addTearDown(identity.dispose);
        final container = setup(
          tester,
          width: spec.$1,
          scale: 1.5,
          language: Locale(spec.$3),
          identityRepository: identity,
          depositWalletRepository: repository,
        );
        tester.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(tester, container);
        open(tester, query);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(DepositWalletScreen)));
        expect(repository.calls, isEmpty);
        final read = find.byKey(const Key('deposit-wallet-read'));
        await reveal(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        expect(repository.calls.length, 1);
        await reveal(tester, find.text(l10n.depositAssetBalance));
        expect(find.text('123.456789012345678901 USDT'), findsOneWidget);
        expect(find.text('10 BNB'), findsOneWidget);
        expect(find.text('2 USDT'), findsOneWidget);
        final amount = find.byKey(const Key('deposit-amount'));
        await reveal(tester, amount);
        await tester.enterText(amount, '1.230000000000000001');
        await tester.pumpAndSettle();
        expect(find.text('1230000000000000001'), findsOneWidget);
        expect(find.text(l10n.depositAllowanceEnough), findsOneWidget);
        final max = find.byKey(const Key('deposit-wallet-max'));
        await reveal(tester, max);
        await tester.tap(max.hitTestable());
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(amount).controller!.text, '123.456789012345678901');
        expect(find.text(l10n.depositAllowanceNeeded), findsOneWidget);
        repository.failure = const FormatException();
        await reveal(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        await reveal(tester, amount);
        expect(tester.widget<TextField>(amount).controller!.text, '123.456789012345678901');
        expect(find.text(l10n.depositReadStale), findsOneWidget);
        expect(tester.widget<OutlinedButton>(max).onPressed, null);
        repository.failure = null;
        await reveal(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        await reveal(tester, amount);
        expect(tester.widget<TextField>(amount).controller!.text, '123.456789012345678901');
        expect(find.text(l10n.depositSubmissionScope), findsOneWidget);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(amount).controller!.text, isEmpty);
        expect(container.read(depositWalletProvider(query)).account, null);
        expect(identity.wallets, 0);
        expect(identity.signatures, 0);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  testWidgets('missing public minimum requires explicit verification and resets at logout', (
    tester,
  ) async {
    final identity = PublicReadIdentity()
      ..restored = const AuthIdentity(
        id: 'wallet',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      );
    addTearDown(identity.dispose);
    final query = depositQuery(minimum: null), repository = TestDepositWalletRepository();
    final c = setup(tester, identityRepository: identity, depositWalletRepository: repository);
    await launch(tester, c);
    open(tester, query);
    await tester.pumpAndSettle();
    final read = find.byKey(const Key('deposit-wallet-read'));
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pumpAndSettle();
    final amount = find.byKey(const Key('deposit-amount')),
        minimum = find.byKey(const Key('deposit-verified-minimum'));
    await reveal(tester, amount);
    await tester.enterText(amount, '1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-smallest-units')), findsNothing);
    await reveal(tester, minimum);
    await tester.enterText(minimum, '2');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-smallest-units')), findsNothing);
    await tester.enterText(minimum, '0.5');
    await tester.pumpAndSettle();
    expect(find.text('1000000000000000000'), findsOneWidget);
    identity.events.add(null);
    await tester.pumpAndSettle();
    await reveal(tester, minimum);
    expect(tester.widget<TextField>(minimum).controller!.text, isEmpty);
    expect(identity.signatures, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final market in TransferMarket.values) {
    testWidgets('deposit catalog entry preserves $market and asset without automatic chain reads', (
      tester,
    ) async {
      final repository = TestDepositWalletRepository();
      final container = setup(tester, depositWalletRepository: repository);
      // Entering the route never reads a wallet automatically.
      await launch(tester, container);
      openFundingInfo(tester.element(find.byType(Navigator).first), market);
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('deposit-wallet-entry-56-USDT'));
      await reveal(tester, entry, scrollKey: 'funding-info-scroll');
      await tester.tap(entry.hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.widget<DepositWalletScreen>(find.byType(DepositWalletScreen)).query.market,
        market,
      );
      expect(repository.calls, isEmpty);
      expect(
        container
            .read(
              depositWalletProvider(
                tester.widget<DepositWalletScreen>(find.byType(DepositWalletScreen)).query,
              ),
            )
            .account,
        null,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets('native wallet Max stays disabled, no token allowance or spender is shown', (
    tester,
  ) async {
    final identity = PublicReadIdentity()
      ..restored = const AuthIdentity(id: 'wallet', walletAddress: accountAddress);
    addTearDown(identity.dispose);
    final repository = TestDepositWalletRepository(), query = depositQuery(native: true);
    final container = setup(
      tester,
      identityRepository: identity,
      depositWalletRepository: repository,
    );
    await launch(tester, container);
    open(tester, query);
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(DepositWalletScreen)));
    final read = find.byKey(const Key('deposit-wallet-read'));
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pumpAndSettle();
    final max = find.byKey(const Key('deposit-wallet-max'));
    await reveal(tester, max);
    expect(tester.widget<OutlinedButton>(max).onPressed, null);
    expect(find.text(l10n.depositNativeMaxUnavailable), findsOneWidget);
    expect(find.text(l10n.depositAllowance), findsNothing);
    expect(find.text(depositVaults[56]!), findsNothing);
    final amount = find.byKey(const Key('deposit-amount'));
    await tester.enterText(amount, '1');
    await tester.pumpAndSettle();
    expect(find.text(l10n.depositNativeNoApproval), findsOneWidget);
    expect(identity.signatures, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('signed-out read opens sign-in but never requests RPC or creates wallet', (
    tester,
  ) async {
    final repository = TestDepositWalletRepository(), identity = PublicReadIdentity();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      depositWalletRepository: repository,
    );
    await launch(tester, container);
    open(tester, depositQuery());
    await tester.pumpAndSettle();
    final read = find.byKey(const Key('deposit-wallet-read'));
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('stop and route disposal invalidate pending wallet balance reads', (tester) async {
    final identity = PublicReadIdentity()
      ..restored = const AuthIdentity(id: 'wallet', walletAddress: accountAddress);
    addTearDown(identity.dispose);
    final repository = TestDepositWalletRepository()..gate = Completer();
    final query = depositQuery();
    final container = setup(
      tester,
      identityRepository: identity,
      depositWalletRepository: repository,
    );
    await launch(tester, container);
    open(tester, query);
    await tester.pumpAndSettle();
    final read = find.byKey(const Key('deposit-wallet-read'));
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pump();
    final stop = find.byKey(const Key('deposit-wallet-stop'));
    await tester.ensureVisible(stop);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(stop.hitTestable());
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(depositWalletProvider(query)).account, null);
    repository.gate = Completer();
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pump();
    Navigator.of(tester.element(find.byType(DepositWalletScreen))).pop();
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.exists(depositWalletProvider(query)), false);
    expect(identity.signatures, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

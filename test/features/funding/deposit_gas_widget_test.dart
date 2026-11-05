import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/presentation/deposit_wallet_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/trade_fixture.dart';
import 'deposit_wallet_widget_test.dart' show PublicReadIdentity, reveal, open;

void main() {
  for (final spec in [(320.0, 844.0, 'en'), (320.0, 844.0, 'zh'), (844.0, 390.0, 'en')]) {
    testWidgets('gas read-only review, input drift, failures and scope isolation fit $spec', (
      tester,
    ) async {
      final identity = PublicReadIdentity()
        ..restored = const AuthIdentity(
          id: 'wallet',
          walletAddress: accountAddress,
          walletKind: WalletKind.external,
        );
      addTearDown(identity.dispose);
      final wallet = TestDepositWalletRepository(),
          gas = TestDepositGasRepository(),
          query = depositQuery();
      final container = setup(
        tester,
        width: spec.$1,
        scale: 1.5,
        language: Locale(spec.$3),
        identityRepository: identity,
        depositWalletRepository: wallet,
        depositGasRepository: gas,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(tester, container);
      open(tester, query);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(DepositWalletScreen)));
      expect(gas.calls, isEmpty);
      final read = find.byKey(const Key('deposit-wallet-read'));
      await reveal(tester, read);
      await tester.tap(read.hitTestable());
      await tester.pumpAndSettle();
      final amount = find.byKey(const Key('deposit-amount'));
      await reveal(tester, amount);
      await tester.enterText(amount, '1.230000000000000001');
      await tester.pumpAndSettle();
      final estimate = find.byKey(const Key('deposit-gas-estimate'));
      await reveal(tester, estimate);
      await tester.tap(estimate.hitTestable());
      await tester.pumpAndSettle();
      expect(gas.calls.single.$3, '1.230000000000000001');
      final step = find.byKey(const Key('deposit-gas-step'));
      await reveal(tester, step);
      expect(find.text(l10n.depositGasDeposit), findsOneWidget);
      await reveal(tester, find.text(l10n.depositGasTotal));
      expect(find.text('0.000025202 BNB'), findsNWidgets(2));
      expect(container.read(depositGasProvider(query)).account, isNotNull);
      await reveal(tester, read);
      await reveal(tester, step);
      expect(gas.calls.length, 1);
      expect(find.text(l10n.depositGasDeposit), findsOneWidget);
      await reveal(tester, amount);
      await tester.enterText(amount, '3');
      await tester.pumpAndSettle();
      await reveal(tester, find.text(l10n.depositGasChangedAmount));
      expect(gas.calls.length, 1);
      gas.failure = const AccountReadFailure('depositGasSimulationFailed');
      await reveal(tester, estimate);
      await tester.tap(estimate.hitTestable());
      await tester.pumpAndSettle();
      await reveal(tester, find.text(l10n.depositGasSimulationFailed));
      expect(container.read(depositGasProvider(query)).stale, true);
      expect(tester.widget<TextField>(amount).controller!.text, '3');
      gas.failure = null;
      await reveal(tester, estimate);
      await tester.tap(estimate.hitTestable());
      await tester.pumpAndSettle();
      await reveal(tester, step);
      expect(find.text(l10n.depositGasReset), findsOneWidget);
      expect(find.text(l10n.depositGasChangedAmount), findsNothing);
      await reveal(tester, find.text(l10n.depositSubmissionScope));
      identity.events.add(null);
      await tester.pumpAndSettle();
      expect(container.read(depositGasProvider(query)).account, null);
      await reveal(tester, amount);
      expect(tester.widget<TextField>(amount).controller!.text, isEmpty);
      expect(identity.signatures, 0);
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  for (final native in [false, true]) {
    testWidgets(
      'next ${native ? 'native deposit' : 'exact approval'} is explicit and never submits',
      (tester) async {
        final identity = PublicReadIdentity()
          ..restored = const AuthIdentity(id: 'wallet', walletAddress: accountAddress);
        addTearDown(identity.dispose);
        final query = depositQuery(native: native),
            snapshot = depositSnapshot(
              query: depositQuery(native: native),
              allowance: BigInt.zero,
            );
        final wallet = TestDepositWalletRepository()..result = snapshot;
        final gas = TestDepositGasRepository()..result = gasQuote(query: query, wallet: snapshot);
        final container = setup(
          tester,
          identityRepository: identity,
          depositWalletRepository: wallet,
          depositGasRepository: gas,
        );
        await launch(tester, container);
        open(tester, query);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(DepositWalletScreen)));
        final read = find.byKey(const Key('deposit-wallet-read'));
        await reveal(tester, read);
        await tester.tap(read.hitTestable());
        await tester.pumpAndSettle();
        final amount = find.byKey(const Key('deposit-amount'));
        await reveal(tester, amount);
        await tester.enterText(amount, '1');
        await tester.pumpAndSettle();
        final estimate = find.byKey(const Key('deposit-gas-estimate'));
        await reveal(tester, estimate);
        await tester.tap(estimate.hitTestable());
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const Key('deposit-gas-step')));
        expect(find.text(native ? l10n.depositGasDeposit : l10n.depositGasApprove), findsOneWidget);
        expect(find.text(l10n.depositGasReset), findsNothing);
        if (native) {
          final max = find.byKey(const Key('deposit-wallet-max'));
          await reveal(tester, max);
          expect(tester.widget<OutlinedButton>(max).onPressed, null);
        }
        await reveal(tester, find.text(l10n.depositSubmissionScope));
        expect(identity.signatures, 0);
        expect(identity.wallets, 0);
        expect(gas.calls.length, 1);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  testWidgets('stop and route exit discard pending gas estimates without signatures', (
    tester,
  ) async {
    final identity = PublicReadIdentity()
      ..restored = const AuthIdentity(id: 'wallet', walletAddress: accountAddress);
    addTearDown(identity.dispose);
    final query = depositQuery(), gas = TestDepositGasRepository()..gate = Completer();
    final container = setup(
      tester,
      identityRepository: identity,
      depositWalletRepository: TestDepositWalletRepository(),
      depositGasRepository: gas,
    );
    await launch(tester, container);
    open(tester, query);
    await tester.pumpAndSettle();
    final read = find.byKey(const Key('deposit-wallet-read'));
    await reveal(tester, read);
    await tester.tap(read.hitTestable());
    await tester.pumpAndSettle();
    final amount = find.byKey(const Key('deposit-amount'));
    await reveal(tester, amount);
    await tester.enterText(amount, '1');
    await tester.pumpAndSettle();
    final estimate = find.byKey(const Key('deposit-gas-estimate'));
    await reveal(tester, estimate);
    await tester.tap(estimate.hitTestable());
    await tester.pump();
    final stop = find.byKey(const Key('deposit-gas-stop'));
    await tester.ensureVisible(stop);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(stop.hitTestable());
    await tester.pumpAndSettle();
    gas.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(depositGasProvider(query)).account, null);
    gas.gate = Completer();
    await reveal(tester, estimate);
    await tester.tap(estimate.hitTestable());
    await tester.pump();
    Navigator.of(tester.element(find.byType(DepositWalletScreen))).pop();
    await tester.pumpAndSettle();
    expect(gas.isCurrent!(), false);
    gas.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.exists(depositGasProvider(query)), false);
    expect(identity.signatures, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

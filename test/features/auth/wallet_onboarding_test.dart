import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/wallet_onboarding_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/identity_repository.dart';
import '../../support/vanta_api.dart';
import '../../support/wallet_connection.dart';
import 'wallet_onboarding_fixture.dart';

import 'package:vanta/features/authorization/application/builder_authorization_provider.dart';

class _LoginIdentity extends TestIdentityRepository {
  @override
  Future<AuthIdentity> ensureWallet() async {
    await super.ensureWallet();
    return onboardingIdentity(WalletKind.embedded);
  }
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('startup without an SDK wallet session enters the signed-out home in $language', (
      tester,
    ) async {
      final connection = TestWalletConnection(address: vantaTestAddress);
      addTearDown(connection.dispose);
      final connector = OnboardingRestorer(connection)..missing = true;
      final h = OnboardingHarness(connector: connector);
      h.identity.restored = AuthIdentity(
        id: 'external-user',
        walletKind: WalletKind.external,
        walletAddress: vantaTestAddress,
      );
      await h.mount(tester, language: language);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-splash')), findsOneWidget);
      connector.restoreGate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byKey(const Key('enable-trading-page')), findsNothing);
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(h.container.read(authProvider).identity, isNull);
      expect(h.container.read(authProvider).failure, isNull);
      expect(h.container.read(authProvider).phase, AuthPhase.signedOut);
      expect(h.identity.logouts, 1);
      expect(connector.restores, 1);
      expect(connector.connects, 0);
      expect(h.authorization.enables, 0);
      expect(h.signer.calls, 0);
      expect(find.text('Main page'), findsOneWidget);
    });
  }

  testWidgets('holds splash for identity and session restoration before entering home', (
    tester,
  ) async {
    final h = OnboardingHarness(verified: true);
    await h.grant();
    h.identity.initializeGate = Completer<void>();
    h.sessions.readGate = Completer<void>();
    await h.mount(tester);
    await tester.pump();
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(find.text('Main page'), findsNothing);
    h.identity.initializeGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    h.sessions.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(h.signer.calls, 0);
    expect(h.authorization.enables, 0);
    h.container.dispose();
  });

  testWidgets('signed out startup enters the public home after the check', (tester) async {
    final h = OnboardingHarness();
    h.identity.restored = null;
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(h.authorization.enables, 0);
  });

  for (final missing in [false, true]) {
    testWidgets('waits for SDK wallet restoration before routing: missing=$missing', (
      tester,
    ) async {
      final connection = TestWalletConnection(address: vantaTestAddress);
      addTearDown(connection.dispose);
      final connector = OnboardingRestorer(connection)..missing = missing;
      final h = OnboardingHarness(connector: connector);
      h.identity.restored = AuthIdentity(
        id: 'external-user',
        walletKind: WalletKind.external,
        walletAddress: vantaTestAddress,
      );
      await h.mount(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-splash')), findsOneWidget);
      expect(connector.restores, 1);
      expect(connector.connects, 0);
      connector.restoreGate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(find.text('Main page'), missing ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('enable-trading-page')), missing ? findsNothing : findsOneWidget);
      expect(connector.connects, 0);
      expect(h.signer.calls, 0);
    });
  }

  testWidgets('unreadable stored credentials settle on the signature page', (tester) async {
    final h = OnboardingHarness();
    h.sessions.failure = const AuthFailure('authNetwork');
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.container.read(vantaApiSessionProvider).status, VantaApiSessionStatus.signedOut);
    expect(h.container.read(walletOnboardingProvider).busy, false);
  });

  testWidgets('missing API configuration settles on the signature page without a false login', (
    tester,
  ) async {
    final h = OnboardingHarness(configured: false);
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byKey(const Key('wallet-verification-error')), findsOneWidget);
    expect(find.text('Main page'), findsNothing);
  });

  for (final granted in [false, true]) {
    for (final verified in [false, true]) {
      testWidgets('external startup grant=$granted verified=$verified resumes the missing step', (
        tester,
      ) async {
        final h = OnboardingHarness(verified: verified);
        if (granted) await h.grant();
        await h.mount(tester);
        await tester.pumpAndSettle();
        expect(h.signer.calls, 0);
        expect(h.authorization.enables, 0);
        if (granted && verified) {
          expect(find.text('Main page'), findsOneWidget);
          h.container.dispose();
          return;
        }
        expect(find.byKey(const Key('wallet-verification-step')), findsOneWidget);
        expect(find.text('Main page'), findsNothing);
        final sign = find.byKey(const Key('enable-trading-sign'));
        await tester.tap(sign);
        await tester.pumpAndSettle();
        if (!granted && !verified) {
          expect(h.signer.calls, 0);
          expect(find.text('Main page'), findsNothing);
          await tester.tap(sign);
          await tester.pumpAndSettle();
        }
        expect(find.text('Main page'), findsOneWidget);
        expect(h.authorization.enables, granted ? 0 : 1);
        expect(h.signer.calls, verified ? 0 : 1);
        h.container.dispose();
      });
    }
  }

  testWidgets('fresh Privy login automatically signs trading and SIWE', (tester) async {
    final h = OnboardingHarness(repository: _LoginIdentity());
    h.identity.restored = null;
    h.signer.gate = Completer<void>();
    await h.mount(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => const LoginScreen(account: SizedBox()))),
            child: const Text('Open login'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('login-google')));
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
    expect(h.identity.wallets, 1);
    expect(h.authorization.enables, 1);
    expect(h.signer.calls, 1);
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.signer.calls, 1);
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open login'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    expect(h.container.read(vantaApiSessionProvider).ready, true);
  });

  testWidgets('an existing Agent without Builder approval resumes the existing enable flow', (
    tester,
  ) async {
    final h = OnboardingHarness(verified: true);
    await h.grant();
    h.builderJournal.records.clear();
    h.container.invalidate(builderApprovalProvider);
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(h.authorization.enables, 1);
    expect(find.text('Main page'), findsOneWidget);
    expect(h.signer.calls, 0);
    h.container.dispose();
  });

  testWidgets('restored Privy shows authorization and signs both steps only after confirmation', (
    tester,
  ) async {
    final h = OnboardingHarness(kind: WalletKind.embedded);
    h.authorization.enableGate = Completer<void>();
    h.signer.gate = Completer<void>();
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.authorization.enables, 1);
    expect(h.signer.calls, 0);
    h.authorization.enableGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.signer.calls, 1);
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(h.authorization.enables, 1);
  });

  testWidgets('restored Privy failure waits for an explicit retry', (tester) async {
    final h = OnboardingHarness(kind: WalletKind.embedded);
    h.authorization.failure = const AccountReadFailure('authWalletRejected');
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(h.authorization.enables, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.authorization.enables, 1);
    expect(h.signer.calls, 0);
    h.authorization.failure = null;
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(h.authorization.enables, 2);
    expect(find.text('Main page'), findsOneWidget);
  });

  testWidgets('SIWE rejection releases loading and retry never repeats an active grant', (
    tester,
  ) async {
    final h = OnboardingHarness(kind: WalletKind.embedded);
    await h.grant();
    h.backend.routes['POST /v1/auth/siwe'] = (_) => json({'message': 'Verification declined'}, 400);
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(h.signer.calls, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(find.text('Verification declined'), findsOneWidget);
    expect(h.container.read(walletOnboardingProvider).busy, false);
    expect(h.authorization.enables, 0);
    h.backend.routes['POST /v1/auth/siwe'] = (_) => json(issued('access-2', 'refresh-2'));
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 2);
    h.container.dispose();
  });

  testWidgets('stored unknown grant is checked without silently replaying a financial write', (
    tester,
  ) async {
    final h = OnboardingHarness(kind: WalletKind.embedded);
    await h.grant(TradingAgentStatus.unknown);
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(h.authorization.checks, 1);
    expect(h.authorization.enables, 0);
    expect(find.text('Main page'), findsNothing);
    h.container.dispose();
  });

  testWidgets('sign button resumes a missing Builder after live check with an active Agent', (
    tester,
  ) async {
    final h = OnboardingHarness();
    await h.grant();
    await h.builderJournal.save(
      vantaTestAddress,
      BuilderApprovalRecord(
        status: BuilderApprovalStatus.unknown,
        maxFeeRate: VantaBuilder.approvalCap,
      ),
    );
    h.authorization.checked = TradingAuthorizationCheck(
      address: vantaTestAddress,
      checkedAt: vantaTestNow,
      futuresReadAccepted: true,
      spotReadAccepted: true,
      agentReady: true,
      builderReady: false,
    );
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(h.authorization.enables, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(h.authorization.checks, 1);
    expect(h.authorization.enables, 1);
    expect(h.authorization.retriedPendingBuilder, true);
    final authorization = h.container.read(tradingAuthorizationProvider);
    expect(authorization.result, TradingAuthorizationResult.acknowledged);
    expect(authorization.failure, isNull);
    expect(h.signer.calls, 0);
    h.container.dispose();
  });

  testWidgets('late signature after wallet change cannot enter the previous wallet home', (
    tester,
  ) async {
    final h = OnboardingHarness(kind: WalletKind.embedded);
    await h.grant();
    h.signer.gate = Completer<void>();
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(h.signer.calls, 0);
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.signer.calls, 1);
    h.identity.events.add(
      const AuthIdentity(
        id: 'other',
        walletKind: WalletKind.external,
        walletAddress: '0x1111111111111111111111111111111111111111',
        signingAvailable: true,
      ),
    );
    await tester.pumpAndSettle();
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsNothing);
    expect(h.sessions.value, isNull);
    expect(h.container.read(walletOnboardingProvider).busy, false);
    expect(h.authorization.enables, 0);
  });
}

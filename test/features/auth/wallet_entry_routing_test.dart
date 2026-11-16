import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';

import '../../support/vanta_api.dart';
import '../../support/wallet_connection.dart';
import 'wallet_onboarding_fixture.dart';

Future<void> _resume(WidgetTester tester, {bool signing = false}) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  if (signing) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

const _inputKey = Key('home-order-input');
const _home = Scaffold(body: TextField(key: _inputKey));

void main() {
  testWidgets('restore timeout retries on the current page with button loading, then recovers', (
    tester,
  ) async {
    final connection = TestWalletConnection(address: vantaTestAddress);
    addTearDown(connection.dispose);
    final connector = OnboardingRestorer(connection)
      ..failure = const AuthFailure('authWalletConnectionTimeout');
    connector.restoreGate.complete();
    final h = OnboardingHarness(connector: connector);
    h.identity.restored = AuthIdentity(
      id: 'external-user',
      walletKind: WalletKind.external,
      walletAddress: vantaTestAddress,
    );
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(connector.restores, 1);
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(
      find.text('Wallet connection setup timed out. Check your network and retry.'),
      findsOneWidget,
    );
    final gate = connector.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(find.byKey(const Key('startup-splash')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(connector.connects, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(find.byKey(const Key('startup-splash')), findsNothing);
    connector.failure = null;
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pumpAndSettle();
    expect(h.container.read(authProvider).identity?.signingAvailable, true);
    expect(connector.connects, 2);
    expect(connector.restores, 1);
    expect(h.signer.calls, 0);
    expect(h.authorization.enables, 0);
  });

  testWidgets('cancel after startup restore failure does not immediately restore again', (
    tester,
  ) async {
    final connection = TestWalletConnection(address: vantaTestAddress);
    addTearDown(connection.dispose);
    final connector = OnboardingRestorer(connection)
      ..failure = const AuthFailure('authWalletConnectionTimeout');
    connector.restoreGate.complete();
    final h = OnboardingHarness(connector: connector);
    h.identity.restored = AuthIdentity(
      id: 'external-user',
      walletKind: WalletKind.external,
      walletAddress: vantaTestAddress,
    );
    await h.mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-trading-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(connector.restores, 1);
    expect(connector.connects, 0);
  });

  for (final kind in WalletKind.values) {
    for (final granted in [false, true]) {
      for (final verified in [false, true]) {
        testWidgets('$kind entry grant=$granted verified=$verified opens only missing steps', (
          tester,
        ) async {
          final h = OnboardingHarness(kind: kind, verified: verified);
          if (granted) await h.grant();
          await h.mount(tester);
          await tester.pumpAndSettle();
          expect(h.authorization.enables, 0);
          expect(h.signer.calls, 0);
          expect(
            find.byKey(const Key('enable-trading-page')),
            granted && verified ? findsNothing : findsOneWidget,
          );
          if (granted && verified) {
            await _resume(tester);
            expect(find.text('Main page'), findsOneWidget);
            expect(h.authorization.enables, 0);
            expect(h.signer.calls, 0);
            h.container.dispose();
            return;
          }
          await tester.tap(find.byKey(const Key('enable-trading-cancel')));
          await tester.pumpAndSettle();
          expect(find.text('Main page'), findsOneWidget);
          await _resume(tester);
          expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
          // Returning to the app while the prompt is open must not stack a new one.
          await _resume(tester);
          expect(find.byKey(const Key('enable-trading-page'), skipOffstage: false), findsOneWidget);
          expect(h.authorization.enables, 0);
          expect(h.signer.calls, 0);
          await tester.tap(find.byKey(const Key('enable-trading-sign')));
          await tester.pumpAndSettle();
          if (kind == WalletKind.external && !granted && !verified) {
            await tester.tap(find.byKey(const Key('enable-trading-sign')));
            await tester.pumpAndSettle();
          }
          expect(find.text('Main page'), findsOneWidget);
          expect(h.authorization.enables, granted ? 0 : 1);
          expect(h.signer.calls, verified ? 0 : 1);
          h.container.dispose();
        });
      }
    }
  }

  testWidgets('ready resume preserves the existing home and its order input', (tester) async {
    final h = OnboardingHarness(verified: true);
    await h.grant();
    await h.mount(tester, home: _home);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_inputKey), '123.45');
    await _resume(tester);
    expect(find.text('123.45'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    h.container.dispose();
  });

  for (final missingGrant in [true, false]) {
    testWidgets(
      'resume recovers lost ${missingGrant ? 'agent' : 'verification'} over existing home',
      (tester) async {
        final h = OnboardingHarness(verified: true);
        await h.grant();
        await h.mount(tester, home: _home);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(_inputKey), '42');
        if (missingGrant) {
          final store = h.container.read(tradingAgentStoreProvider);
          final agent = (await h.container.read(tradingAgentProvider.future))!;
          await store.setStatus(agent, TradingAgentStatus.rejected);
          h.container.invalidate(tradingAgentProvider);
        } else {
          final repository = h.container.read(vantaApiSessionRepositoryProvider)!;
          await repository.signOut();
          repository.onSessionLost!(vantaTestAddress.toLowerCase());
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('enable-trading-page')), findsNothing);
        await _resume(tester);
        expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
        expect(h.authorization.enables, 0);
        expect(h.signer.calls, 0);
        await tester.tap(find.byKey(const Key('enable-trading-cancel')));
        await tester.pumpAndSettle();
        expect(find.text('42'), findsOneWidget);
        // Cancel allows browsing this visit, but the next entry checks again.
        await _resume(tester);
        expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
        h.container.dispose();
      },
    );
  }

  testWidgets('entry waits for SDK restoration before opening missing authorization', (
    tester,
  ) async {
    final connection = TestWalletConnection(address: vantaTestAddress);
    addTearDown(connection.dispose);
    final connector = OnboardingRestorer(connection);
    final h = OnboardingHarness(connector: connector);
    await h.mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-trading-cancel')));
    await tester.pumpAndSettle();
    h.identity.events.add(
      AuthIdentity(
        id: 'test-user',
        walletKind: WalletKind.external,
        walletAddress: vantaTestAddress,
      ),
    );
    await tester.pumpAndSettle();
    await _resume(tester);
    expect(connector.restores, 1);
    expect(find.text('Main page'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    connector.restoreGate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    expect(connector.connects, 0);
    h.container.dispose();
  });

  testWidgets('returning from wallet signing keeps a single verification route', (tester) async {
    final h = OnboardingHarness();
    await h.grant();
    await h.mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-trading-cancel')));
    await tester.pumpAndSettle();
    await _resume(tester);
    h.signer.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('enable-trading-sign')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await _resume(tester, signing: true);
    expect(h.signer.calls, 1);
    expect(find.byKey(const Key('enable-trading-page'), skipOffstage: false), findsOneWidget);
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page'), skipOffstage: false), findsNothing);
    expect(h.authorization.enables, 0);
    h.container.dispose();
  });

  testWidgets('resume leaves the current pushed page in control', (tester) async {
    final h = OnboardingHarness();
    await h.mount(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Current page'))),
            ),
            child: const Text('Open page'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-trading-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open page'));
    await tester.pumpAndSettle();
    await _resume(tester);
    expect(find.text('Current page'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page'), skipOffstage: false), findsNothing);
    expect(h.authorization.enables, 0);
    expect(h.signer.calls, 0);
    h.container.dispose();
  });

  testWidgets('signed-out resume keeps the public home', (tester) async {
    final h = OnboardingHarness();
    h.identity.restored = null;
    await h.mount(tester);
    await tester.pumpAndSettle();
    await _resume(tester);
    expect(find.text('Main page'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    h.container.dispose();
  });
}

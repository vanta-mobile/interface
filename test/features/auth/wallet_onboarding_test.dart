import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/wallet_onboarding_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';

import '../../support/wallet_connection.dart';

import 'package:vanta/features/auth/presentation/startup_screen.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_agents.dart';
import '../../support/trading_authorization.dart';
import '../../support/vanta_api.dart';

AuthIdentity _identity(WalletKind kind) => AuthIdentity(
  id: 'test-user',
  walletAddress: vantaTestAddress,
  walletKind: kind,
  signingAvailable: true,
);

class _LoginIdentity extends TestIdentityRepository {
  @override
  Future<AuthIdentity> ensureWallet() async {
    await super.ensureWallet();
    return _identity(WalletKind.embedded);
  }
}

class _Store extends MemoryStore {
  Completer<void>? readGate;
  Object? failure;
  @override
  Future<VantaApiCredentials?> read() async {
    await readGate?.future;
    if (failure case final error?) throw error;
    return super.read();
  }
}

class _Harness {
  _Harness({
    WalletKind kind = WalletKind.external,
    bool verified = false,
    WalletConnector? connector,
    bool configured = true,
    TestIdentityRepository? repository,
  }) : identity = repository ?? TestIdentityRepository() {
    identity.restored = _identity(kind);
    if (verified) {
      sessions.value = VantaApiCredentials(
        address: vantaTestAddress.toLowerCase(),
        accessToken: 'fixture-access',
        refreshToken: 'fixture-refresh',
        accessExpiresAt: vantaTestNow.add(const Duration(hours: 1)),
      );
    }
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        privyConfigurationProvider.overrideWithValue(
          const PrivyConfiguration(appId: 'fixture', clientId: 'fixture'),
        ),
        if (connector != null) walletConnectorProvider.overrideWithValue(connector),
        tradingAgentStoreProvider.overrideWithValue(agents.store(() => vantaTestNow)),
        tradingAgentClockProvider.overrideWithValue(() => vantaTestNow),
        tradingAuthorizationRepositoryProvider.overrideWithValue(authorization),
        vantaApiSessionRepositoryProvider.overrideWithValue(
          configured
              ? vantaTestRepository(
                  backend,
                  store: sessions,
                  signer: signer,
                  now: () => vantaTestNow,
                )
              : null,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await identity.dispose();
    });
  }
  final TestIdentityRepository identity;
  final authorization = TestTradingAuthorizationRepository();
  final agents = MemoryTradingAgentStorage();
  final sessions = _Store();
  final backend = Backend();
  final signer = KeySigner();
  late final ProviderContainer container;

  Future<void> grant([TradingAgentStatus status = TradingAgentStatus.active]) async {
    final store = container.read(tradingAgentStoreProvider);
    final agent = await store.prepare(
      'test-user',
      vantaTestAddress,
      vantaTestNow.add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    if (status == TradingAgentStatus.active) await store.setStatus(agent, status);
  }

  Future<void> mount(WidgetTester tester, {Widget? home, String language = 'en'}) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: vantaTheme(),
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StartupScreen(home: home ?? const Scaffold(body: Text('Main page'))),
          ),
        ),
      );
}

class _Restorer extends TestWalletConnector implements WalletSessionRestorer {
  _Restorer(super.connection);
  final restoreGate = Completer<void>();
  int restores = 0;
  bool missing = false;
  @override
  Future<WalletConnection?> restore(BuildContext context, {required String expectedAddress}) async {
    restores++;
    expect(expectedAddress, connection.address);
    await restoreGate.future;
    if (failure case final error?) throw error;
    return missing ? null : connection;
  }
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('startup without an SDK wallet session enters the signed-out home in $language', (
      tester,
    ) async {
      final connection = TestWalletConnection(address: vantaTestAddress);
      addTearDown(connection.dispose);
      final connector = _Restorer(connection)..missing = true;
      final h = _Harness(connector: connector);
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
    final h = _Harness(verified: true);
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
    final h = _Harness();
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
      final connector = _Restorer(connection)..missing = missing;
      final h = _Harness(connector: connector);
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
    final h = _Harness();
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
    final h = _Harness(configured: false);
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
        final h = _Harness(verified: verified);
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

  testWidgets('fresh Privy login silently completes trading and SIWE before closing login', (
    tester,
  ) async {
    final h = _Harness(repository: _LoginIdentity());
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
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open login'), findsOneWidget);
    expect(find.byKey(const Key('enable-trading-page')), findsNothing);
    expect(h.container.read(vantaApiSessionProvider).ready, true);
  });

  testWidgets('Privy silently signs trading then SIWE once and holds splash until both settle', (
    tester,
  ) async {
    final h = _Harness(kind: WalletKind.embedded);
    h.authorization.enableGate = Completer<void>();
    h.signer.gate = Completer<void>();
    await h.mount(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    expect(h.authorization.enables, 1);
    expect(h.signer.calls, 0);
    h.authorization.enableGate!.complete();
    await tester.pumpAndSettle();
    expect(h.signer.calls, 1);
    expect(find.byKey(const Key('startup-splash')), findsOneWidget);
    h.signer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Main page'), findsOneWidget);
    expect(h.authorization.enables, 1);
  });

  testWidgets('Privy failure stops automatic retries and offers a working explicit retry', (
    tester,
  ) async {
    final h = _Harness(kind: WalletKind.embedded);
    h.authorization.failure = const AccountReadFailure('authWalletRejected');
    await h.mount(tester);
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
    final h = _Harness(kind: WalletKind.embedded);
    await h.grant();
    h.backend.routes['POST /v1/auth/siwe'] = (_) => json({'message': 'Verification declined'}, 400);
    await h.mount(tester);
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
    final h = _Harness(kind: WalletKind.embedded);
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

  testWidgets('late signature after wallet change cannot enter the previous wallet home', (
    tester,
  ) async {
    final h = _Harness(kind: WalletKind.embedded);
    await h.grant();
    h.signer.gate = Completer<void>();
    await h.mount(tester);
    await tester.pumpAndSettle();
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

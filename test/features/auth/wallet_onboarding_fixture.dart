import 'package:vanta/features/authorization/application/builder_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';

import '../../support/builder.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_connection.dart';
import 'package:vanta/features/auth/presentation/startup_screen.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_agents.dart';
import '../../support/trading_authorization.dart';
import '../../support/vanta_api.dart';
import '../../support/wallet_connection.dart';

AuthIdentity onboardingIdentity(WalletKind kind) => AuthIdentity(
  id: 'test-user',
  walletAddress: vantaTestAddress,
  walletKind: kind,
  signingAvailable: true,
);

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

class OnboardingHarness {
  OnboardingHarness({
    WalletKind kind = WalletKind.external,
    bool verified = false,
    WalletConnector? connector,
    bool configured = true,
    TestIdentityRepository? repository,
  }) : identity = repository ?? TestIdentityRepository() {
    identity.restored = onboardingIdentity(kind);
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
        builderApprovalJournalProvider.overrideWithValue(builderJournal),
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
  final builderJournal = MemoryBuilderApprovalJournal();
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
    if (status == TradingAgentStatus.active) {
      await store.setStatus(agent, status);
      await builderJournal.save(
        vantaTestAddress,
        BuilderApprovalRecord(
          status: BuilderApprovalStatus.approved,
          maxFeeRate: VantaBuilder.approvalCap,
        ),
      );
    }
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

class OnboardingRestorer extends TestWalletConnector implements WalletSessionRestorer {
  OnboardingRestorer(super.connection);
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

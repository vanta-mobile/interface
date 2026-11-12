import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/authorization/presentation/enable_trading_screen.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/reown_modal.dart';
import '../../support/trading_agents.dart';
import '../../support/wallet_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('missing peer session releases signing and leaves a working reconnect action', (
    tester,
  ) async {
    final modal = TestReownModal();
    final preferences = MemoryWalletPreferences();
    final repository = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: preferences,
    );
    final connection = ReownWalletConnection(modal, modal.address, '56');
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(repository),
        tradingAgentStoreProvider.overrideWithValue(
          MemoryTradingAgentStorage().store(DateTime.now),
        ),
        vantaApiSessionRepositoryProvider.overrideWithValue(null),
        // Serve the signing window's server time so the flow reaches the wallet.
        tradingAuthorizationRepositoryProvider.overrideWith((ref) {
          final client = MockClient((request) async {
            expect(request.url.path, endsWith('/time'));
            return http.Response(
              jsonEncode({'serverTime': DateTime.now().millisecondsSinceEpoch}),
              200,
            );
          });
          final futures = AsterAccountService(client: client);
          final spot = AsterSpotService(client: client);
          ref.onDispose(() {
            futures.close();
            spot.close();
          });
          return AsterTradingAuthorizationRepository(
            futures,
            spot,
            repository.signWalletRequest,
            agents: ref.watch(tradingAgentStoreProvider),
            signingPreparation: repository,
            nonces: AsterReadNonces(),
          );
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
      await modal.dispose();
    });
    container.read(authProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EnableTradingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final connected = await repository.loginWithWallet(connection);
    // A repository connection is normally attached by the auth controller.
    // Refresh reconciles it here, without opening wallet selection in a test.
    await container.read(authProvider.notifier).bootstrap();
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.signingAvailable, true);
    modal.sdk.pingGate = Completer<void>();
    // The wallet launched for the request no longer knows the topic.
    modal.gate = Completer<void>();
    final sign = find.byKey(const Key('enable-trading-sign'));
    await tester.tap(sign);
    // Relay preparation and the request dispatch take a few microtask turns.
    for (var turn = 0; turn < 10 && modal.sdk.pings == 0; turn++) {
      await tester.pump();
    }
    expect(tester.widget<AuthActionButton>(sign).busy, true);
    expect(modal.sdk.pings, 1);
    expect(modal.requests, hasLength(1));
    // WalletConnect metadata remains "connected", while the wallet no longer
    // recognizes the topic. This used to leave the action spinning indefinitely.
    modal.sdk.pingFailure = JsonRpcError(code: 7001, message: 'Session not found');
    modal.sdk.pingGate!.complete();
    await tester.pumpAndSettle();
    final auth = container.read(authProvider);
    expect(auth.identity?.id, connected.id);
    expect(auth.identity?.walletAddress, connected.walletAddress);
    expect(auth.identity?.needsWalletConnection, true);
    expect(auth.identity?.signingAvailable, false);
    expect(modal.isConnected, true);
    expect(modal.requests, hasLength(1));
    expect(tester.widget<AuthActionButton>(sign).busy, false);
    expect(tester.widget<AuthActionButton>(sign).label, 'Connect wallet');
    expect(tester.widget<AuthActionButton>(sign).onPressed, isNotNull);
    expect(find.text('Wallet connected'), findsNothing);
    expect(preferences.value?.address?.toLowerCase(), modal.address.toLowerCase());
    // A process restart retains public metadata, but cannot resurrect a signer.
    final restarted = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: preferences,
    );
    addTearDown(restarted.dispose);
    expect((await restarted.initialize())?.signingAvailable, false);
    // This attempt stopped before nonce/signature/POST. The persisted prepared
    // journal permits a new explicit signature after reconnect, not a spurious
    // unknown-outcome check that would leave onboarding stuck.
    final replacementModal = TestReownModal()..address = modal.address;
    final replacement = ReownWalletConnection(replacementModal, modal.address, '56');
    addTearDown(replacementModal.dispose);
    await repository.loginWithWallet(replacement);
    await container.read(authProvider.notifier).bootstrap();
    await tester.pumpAndSettle();
    expect(container.read(authProvider).identity?.signingAvailable, true);
    expect(
      (await container.read(tradingAgentProvider.future))?.status,
      TradingAgentStatus.prepared,
    );
    expect(container.read(tradingAuthorizationProvider).result, isNull);
    expect(tester.widget<AuthActionButton>(sign).busy, false);
    expect(tester.widget<AuthActionButton>(sign).label, 'Open wallet to sign');
    await replacement.release();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  test('resume never probes or downgrades an idle wallet session', () async {
    final modal = TestReownModal();
    final preferences = MemoryWalletPreferences();
    final repository = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: preferences,
    );
    final connection = ReownWalletConnection(modal, modal.address, '56');
    final changes = <AuthIdentity?>[];
    final subscription = repository.changes.listen(changes.add);
    addTearDown(() async {
      await subscription.cancel();
      await repository.dispose();
      await modal.dispose();
    });
    final identity = await repository.loginWithWallet(connection);
    // A backgrounded wallet cannot answer. That silence is not a disconnect.
    modal.sdk.pingFailure = StateError('Wallet offline');
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(modal.sdk.pings, 0);
    expect(connection.isCurrent, true);
    expect(connection.needsReconnect, false);
    expect(changes.where((change) => change?.signingAvailable != true), isEmpty);
    expect((await repository.initialize())?.id, identity.id);
    expect(preferences.value?.address?.toLowerCase(), modal.address.toLowerCase());
    expect(modal.disconnections, 0);
    await connection.release();
  });
}

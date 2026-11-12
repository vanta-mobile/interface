import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';

import '../../support/onboarding.dart';
import '../../support/trading_agents.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/wallet_configuration.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_signatures.dart';
import '../../support/wallet_connection.dart';

void main() {
  testWidgets('EOA needs only the explicit trading signature without Privy configuration', (
    tester,
  ) async {
    final wallet = _SigningWallet();
    final identity = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: MemoryWalletPreferences(),
      create: (_) => throw TestFailure('EOA flow must not initialize Privy'),
    );
    final now = DateTime.utc(2026, 11, 9);
    final requests = <http.Request>[];
    final submit = Completer<void>();
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/time')) {
        return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/fapi/v3/registerAndApproveAgent');
      final parameters = Uri.splitQueryString(request.body);
      expect(parameters['user'], fixtureMaster);
      expect(parameters['agentAddress'], fixtureMaster);
      expect(parameters['canWithdraw'], 'false');
      expect(parameters['canSpotTrade'], 'true');
      expect(parameters['canPerpTrade'], 'true');
      await submit.future;
      return http.Response('{"code":200,"msg":"success"}', 200);
    });
    final futures = AsterAccountService(client: client);
    final spot = AsterSpotService(client: client);
    final authorization = AsterTradingAuthorizationRepository(
      futures,
      spot,
      identity.signWalletRequest,
      nonces: AsterReadNonces(),
      now: () => now,
    );
    final container = ProviderContainer(
      overrides: [
        vantaApiSessionProvider.overrideWith(VerifiedVantaSession.new),
        tradingAgentStoreProvider.overrideWithValue(
          MemoryTradingAgentStorage().store(DateTime.now),
        ),
        identityRepositoryProvider.overrideWithValue(identity),
        walletConnectorProvider.overrideWithValue(TestWalletConnector(wallet)),
        privyConfigurationProvider.overrideWithValue(
          const PrivyConfiguration(appId: '', clientId: ''),
        ),
        walletConfigurationProvider.overrideWithValue(const WalletConfiguration(projectId: 'test')),
        tradingAuthorizationRepositoryProvider.overrideWithValue(authorization),
        tradingAuthorizationClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(() async {
      container.dispose();
      futures.close();
      spot.close();
      await identity.dispose();
      await wallet.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(account: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final connect = find.byKey(const Key('connect-external-wallet'));
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enable-trading-page')), findsOneWidget);
    expect(wallet.personalSigns, 0);
    expect(wallet.typedSigns, 0);
    expect(requests, isEmpty);

    final enable = find.byKey(const Key('enable-trading-sign'));
    await tester.tap(enable);
    // Let the server-time read and wallet signature reach the held POST.
    for (var i = 0; i < 10 && requests.length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(wallet.personalSigns, 0);
    expect(wallet.typedSigns, 1);
    expect(container.read(tradingAuthorizationProvider).busy, true);
    await tester.tap(enable);
    await tester.pump();
    expect(wallet.typedSigns, 1);
    submit.complete();
    await tester.pumpAndSettle();
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
    expect(requests.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _SigningWallet extends TestWalletConnection {
  _SigningWallet() : super(address: fixtureMaster);

  @override
  Future<String> signTypedData(Map<String, Object?> data) async {
    typedSigns++;
    typedData = data;
    return fixtureSign(data);
  }
}

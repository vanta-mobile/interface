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
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/presentation/auth_controls.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_signatures.dart';
import '../../support/identity_repository.dart';

const _identity = AuthIdentity(id: 'user-1', walletAddress: fixtureMaster, signingAvailable: true);

class _SigningIdentity extends TestIdentityRepository {
  _SigningIdentity({required this.hasWallet});
  final bool hasWallet;
  int signatures = 0;

  @override
  Future<AuthIdentity> loginWithSocial(SocialLoginProvider provider) async {
    await super.loginWithSocial(provider);
    return hasWallet ? _identity : identityWithoutWallet;
  }

  @override
  Future<AuthIdentity> verifyCode(String email, String code) async {
    await super.verifyCode(email, code);
    return hasWallet ? _identity : identityWithoutWallet;
  }

  @override
  Future<AuthIdentity> ensureWallet() async {
    await super.ensureWallet();
    return _identity;
  }

  @override
  Future<String> signWalletRequest({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    signatures++;
    return fixtureWalletSign(expectedAddress: expectedAddress, typedData: typedData);
  }
}

void main() {
  for (final method in ['email', 'google', 'x', 'restored']) {
    for (final hasWallet in [false, true]) {
      testWidgets('$method with existing wallet $hasWallet signs only after a fresh login', (
        tester,
      ) async {
        final identity = _SigningIdentity(hasWallet: hasWallet);
        if (method == 'restored') identity.restored = hasWallet ? _identity : identityWithoutWallet;
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
          expect(
            parameters['expired'],
            '${now.add(const Duration(days: 30)).millisecondsSinceEpoch}',
          );
          await submit.future;
          return http.Response('{"code":200}', 200);
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
            identityRepositoryProvider.overrideWithValue(identity),
            privyConfigurationProvider.overrideWithValue(
              const PrivyConfiguration(appId: 'fixture', clientId: 'fixture'),
            ),
            tradingAuthorizationRepositoryProvider.overrideWithValue(authorization),
            tradingAuthorizationClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(() async {
          container.dispose();
          futures.close();
          spot.close();
          await identity.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: vantaTheme(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(account: Text('Account settings')),
                      ),
                    ),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
        expect(identity.signatures, 0);
        expect(requests, isEmpty);
        if (method == 'restored') {
          expect(find.text('Account settings'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          return;
        }
        if (method == 'email') {
          await tester.enterText(find.byKey(const Key('login-email')), 'test@example.com');
          await tester.tap(find.byKey(const Key('send-email-code')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('login-code')), '123456');
          await tester.pump();
          await tester.tap(find.byKey(const Key('verify-email-code')));
        } else {
          final button = find.byKey(Key('login-$method'));
          await tester.ensureVisible(button);
          await tester.tap(button);
        }
        for (var i = 0; i < 30 && requests.length < 2; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(identity.wallets, hasWallet ? 0 : 1);
        expect(identity.signatures, 1);
        expect(requests.length, 2);
        await tester.pump();
        final enable = find.byKey(const Key('enable-trading-sign'));
        expect(tester.widget<AuthActionButton>(enable).busy, true);
        await tester.tap(enable);
        await tester.pump();
        expect(identity.signatures, 1);
        submit.complete();
        await tester.pumpAndSettle();
        expect(
          container.read(tradingAuthorizationProvider).result,
          TradingAuthorizationResult.acknowledged,
        );
        expect(find.byKey(const Key('enable-trading-page')), findsNothing);
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

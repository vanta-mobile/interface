import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/reown_modal.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final outcome in ['approved', 'rejected', 'cancelled', 'unknown']) {
    test(
      'Arbitrum EOA approval $outcome precedes nonce, one signature and financial dispatch',
      () async {
        final modal = TestReownModal()
          ..address = fixtureMaster
          ..selectedChainId = '42161'
          ..approvedChain = '42161';
        final connection = ReownWalletConnection(modal, fixtureMaster, '42161');
        final identity = PrivyIdentityRepository(
          const PrivyConfiguration(appId: '', clientId: ''),
          preferences: MemoryWalletPreferences(),
          create: (_) => throw TestFailure('EOA must not initialize Privy'),
        );
        final connected = await identity.loginWithWallet(connection);
        var current = true;
        final now = DateTime.utc(2026, 11, 9);
        final operations = <String>[];
        final gate = Completer<void>();
        modal.onRequest = (request) async {
          operations.add(request.method);
          if (request.method == 'wallet_switchEthereumChain') {
            await gate.future;
            if (outcome == 'rejected') throw JsonRpcError(code: 4001, message: 'Switch declined');
            if (outcome == 'cancelled') current = false;
            modal.approvedAccounts = ['eip155:42161:$fixtureMaster', 'eip155:56:$fixtureMaster'];
            modal.selectedChainId = '56';
            modal.changed();
            return null;
          }
          expect(modal.chain, 'eip155:56');
          expect(request.method, 'eth_signTypedData_v4');
          final data = jsonDecode((request.params as List).last as String) as Map<String, dynamic>;
          expect((data['domain'] as Map)['chainId'], 56);
          return fixtureSign(data);
        };
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/time')) {
            operations.add('time');
            return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
          }
          operations.add('POST');
          expect(request.method, 'POST');
          final parameters = Uri.splitQueryString(request.body);
          expect(parameters['canWithdraw'], 'false');
          expect(parameters['signatureChainId'], '56');
          if (outcome == 'unknown') throw http.ClientException('Response lost');
          return http.Response('{"code":200}', 200);
        });
        final futures = AsterAccountService(client: client);
        final spot = AsterSpotService(client: client);
        final repository = AsterTradingAuthorizationRepository(
          futures,
          spot,
          identity.signWalletRequest,
          signingPreparation: identity,
          nonces: AsterReadNonces(),
          now: () => now,
        );
        addTearDown(() async {
          futures.close();
          spot.close();
          await identity.dispose();
          await modal.dispose();
        });
        final pending = repository.enable(
          review: TradingAuthorizationReview(
            identity: connected,
            preparedAt: now,
            expiresAt: now.add(const Duration(days: 30)),
          ),
          isCurrent: () => current,
        );
        final verification = outcome == 'rejected' || outcome == 'cancelled'
            ? expectLater(
                pending,
                throwsA(
                  isA<AccountReadFailure>().having(
                    (e) => e.key,
                    'key',
                    outcome == 'rejected' ? 'authWalletRejected' : 'authWalletChanged',
                  ),
                ),
              )
            : expectLater(
                pending,
                completion(
                  outcome == 'unknown'
                      ? TradingAuthorizationResult.unknown
                      : TradingAuthorizationResult.acknowledged,
                ),
              );
        await Future<void>.delayed(Duration.zero);
        expect(operations, ['wallet_switchEthereumChain']);
        gate.complete();
        await verification;
        expect(
          operations,
          outcome == 'rejected' || outcome == 'cancelled'
              ? ['wallet_switchEthereumChain']
              : ['wallet_switchEthereumChain', 'time', 'eth_signTypedData_v4', 'POST'],
        );
      },
    );
  }
}

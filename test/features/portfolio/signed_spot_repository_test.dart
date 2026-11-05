import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_repository.dart';
import 'package:vanta/features/portfolio/data/signed_spot_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';
import '../../support/wallet_connection.dart';

void main() {
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test(
    'Spot uses sapi host, server time and exact signed query, sharing nonces with Perp',
    () async {
      final signed = <Map<String, Object?>>[];
      final requests = <http.Request>[];
      http.Client client(bool spot) => MockClient((request) async {
        requests.add(request);
        expect(request.url.host, spot ? 'sapi.asterdex.com' : 'fapi.asterdex.com');
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        final time = request.url.path.endsWith('/time');
        if (time) expect(request.url.path, spot ? '/api/v3/time' : '/fapi/v3/time');
        return http.Response(
          jsonEncode(
            time
                ? {'serverTime': 1793620800123}
                : spot
                ? spotPayload()
                : request.url.path.endsWith('/exchangeInfo')
                ? contractPayload()
                : {'assets': <Object?>[], 'positions': <Object?>[]},
          ),
          200,
        );
      });
      final spotService = AsterSpotService(client: client(true));
      final perpService = AsterAccountService(client: client(false));
      addTearDown(spotService.close);
      addTearDown(perpService.close);
      Future<String> sign({
        required String expectedAddress,
        required Map<String, Object?> typedData,
      }) async {
        expect(expectedAddress, accountAddress);
        signed.add(typedData);
        return TestWalletConnection.signature;
      }

      final nonces = AsterReadNonces();
      final spot = SignedSpotRepository(spotService, sign, nonces: nonces);
      final perp = SignedAccountRepository(perpService, sign, nonces: nonces);
      final result = await spot.read(
        address: accountAddress,
        isCurrent: () => true,
        onStep: (_) {},
      );
      await perp.read(address: accountAddress, isCurrent: () => true, onStep: (_) {});
      await spot.read(address: accountAddress, isCurrent: () => true, onStep: (_) {});
      final reads = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
      final metadata = requests.singleWhere((r) => r.url.path.endsWith('/exchangeInfo'));
      expect(metadata.url.queryParameters.containsKey('signature'), false);
      expect(reads.map((r) => r.url.path), [
        '/api/v3/account',
        '/fapi/v3/accountWithJoinMargin',
        '/api/v3/account',
      ]);
      for (var i = 0; i < reads.length; i++) {
        final params = reads[i].url.queryParameters;
        expect(params['nonce'], '${1793620800123000 + i}');
        expect(params['user'], accountAddress);
        expect(params['signer'], accountAddress);
        expect(
          (signed[i]['message']! as Map)['msg'],
          reads[i].url.query.split('&signature=').first,
        );
        expect((signed[i]['domain']! as Map)['chainId'], 1666);
      }
      expect(result.balances.first.total.toString(), '0.010000000000000001');
    },
  );

  test('wallet cancellation or change prevents Spot signed request', () async {
    for (final cancelled in [true, false]) {
      var calls = 0;
      var current = true;
      final service = AsterSpotService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"serverTime":1793620800123}', 200);
        }),
      );
      final repository = SignedSpotRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        if (cancelled) throw const AuthFailure('authWalletCancelled');
        current = false;
        return TestWalletConnection.signature;
      });
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
        throwsA(failure(cancelled ? 'authWalletCancelled' : 'authWalletChanged')),
      );
      expect(calls, 1);
      service.close();
    }
  });

  test(
    'UTF-8 asset names are decoded without charset and invalid money yields safe failure',
    () async {
      var invalid = false;
      final service = AsterSpotService(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode(
                request.url.path.endsWith('/time')
                    ? {'serverTime': 1793620800123}
                    : {
                        'balances': [
                          {'asset': '币安人生', 'free': invalid ? '-1' : '0', 'locked': '2'},
                        ],
                      },
              ),
            ),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      final repository = SignedSpotRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      expect(
        (await repository.read(
          address: accountAddress,
          isCurrent: () => true,
          onStep: (_) {},
        )).balances.single.asset,
        '币安人生',
      );
      invalid = true;
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(failure('accountDataInvalid')),
      );
    },
  );

  test('late Spot response after a wallet change is rejected', () async {
    var current = true;
    final gate = Completer<http.Response>();
    final service = AsterSpotService(
      client: MockClient(
        (request) async => request.url.path.endsWith('/time')
            ? http.Response('{"serverTime":1793620800123}', 200)
            : gate.future,
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final pending = repository.read(
      address: accountAddress,
      isCurrent: () => current,
      onStep: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    gate.complete(http.Response(jsonEncode(spotPayload()), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });
}

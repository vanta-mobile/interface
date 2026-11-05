import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_position_adl_repository.dart';
import 'package:vanta/features/portfolio/domain/position_adl.dart';

import '../../support/aster_account.dart';
import '../../support/position_adl.dart';
import '../../support/position_risk.dart';
import '../../support/wallet_connection.dart';

void main() {
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test(
    'ADL is a separate GET with exact signed bytes, current wallet and shared unique nonce',
    () async {
      final requests = <http.Request>[];
      final signed = <Map<String, Object?>>[];
      final nonces = AsterReadNonces()..next(1793620800123);
      final service = AsterAccountService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.followRedirects, false);
          expect(request.url.host, 'fapi.asterdex.com');
          return http.Response(
            jsonEncode(switch (request.url.path) {
              '/fapi/v3/time' => {'serverTime': 1793620800123},
              '/fapi/v3/adlQuantile' => [positionAdlRow()],
              _ => throw StateError('Unexpected endpoint'),
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final now = DateTime.utc(2026, 11, 3);
      final repository = SignedPositionAdlRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          signed.add(typedData);
          return TestWalletConnection.signature;
        },
        nonces: nonces,
        now: () => now,
      );
      final result = await repository.read(
        address: accountAddress,
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.receivedAt, now);
      expect(result.levelFor(positionRiskFixture().positions.first), 4);
      expect(requests.length, 2);
      final read = requests.last;
      expect(read.url.queryParameters, {
        'nonce': '1793620800123001',
        'user': accountAddress,
        'signer': accountAddress,
        'signature': TestWalletConnection.signature,
      });
      expect((signed.single['message']! as Map)['msg'], read.url.query.split('&signature=').first);
      expect((signed.single['domain']! as Map)['chainId'], 1666);
    },
  );

  test('empty success and invalid data are distinguished without metadata calls', () async {
    for (final empty in [true, false]) {
      final service = AsterAccountService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/time')
                  ? {'serverTime': 1793620800123}
                  : empty
                  ? []
                  : [
                      positionAdlRow()..['adlQuantile'] = {'BOTH': 5},
                    ],
            ),
            200,
          ),
        ),
      );
      final repository = SignedPositionAdlRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      final pending = repository.read(
        address: accountAddress,
        isCurrent: () => true,
        onStep: (_) {},
      );
      if (empty) {
        expect((await pending).symbols, isEmpty);
      } else {
        await expectLater(pending, throwsA(failure('accountDataInvalid')));
      }
      service.close();
    }
  });

  test('wallet refusal and identity changes before submission never reach ADL API', () async {
    for (final rejected in [true, false]) {
      var current = true;
      var reads = 0;
      final service = AsterAccountService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/adlQuantile')) reads++;
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }),
      );
      final repository = SignedPositionAdlRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        if (rejected) throw const AuthFailure('authWalletRejected');
        current = false;
        return TestWalletConnection.signature;
      });
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
        throwsA(failure(rejected ? 'authWalletRejected' : 'authWalletChanged')),
      );
      expect(reads, 0);
      service.close();
    }
  });

  test('ADL reply after wallet change is discarded', () async {
    var current = true;
    final gate = Completer<http.Response>();
    final service = AsterAccountService(
      client: MockClient(
        (r) async => r.url.path.endsWith('/time')
            ? http.Response(jsonEncode({'serverTime': 1793620800123}), 200)
            : gate.future,
      ),
    );
    addTearDown(service.close);
    final repository = SignedPositionAdlRepository(
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
    gate.complete(http.Response(jsonEncode([positionAdlRow()]), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });
}

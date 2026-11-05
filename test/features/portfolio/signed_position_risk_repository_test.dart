import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_position_risk_repository.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/position_risk.dart';
import '../../support/wallet_connection.dart';

void main() {
  test('empty signed baseline retains contract metadata for a first streamed position', () async {
    final service = AsterAccountService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(switch (request.url.path) {
            '/fapi/v3/time' => {'serverTime': 1793620800123},
            '/fapi/v3/exchangeInfo' => contractPayload(),
            _ => <Object?>[],
          }),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedPositionRiskRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final result = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(result.positions, isEmpty);
    expect(result.units['BTCUSDT']?.base, 'BTC');
    expect(() => result.units.clear(), throwsUnsupportedError);
  });

  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test('GET all position risk signs exact bytes and loads contract units', () async {
    final requests = <http.Request>[];
    final signed = <Map<String, Object?>>[];
    final service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        expect(request.url.host, 'fapi.asterdex.com');
        return http.Response(
          jsonEncode(switch (request.url.path) {
            '/fapi/v3/time' => {'serverTime': 1793620800123},
            '/fapi/v3/exchangeInfo' => contractPayload(),
            '/fapi/v3/positionRisk' => [positionRiskRow()],
            _ => throw StateError('unexpected path'),
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final repository = SignedPositionRiskRepository(service, ({
      required expectedAddress,
      required typedData,
    }) async {
      expect(expectedAddress, accountAddress);
      signed.add(typedData);
      return TestWalletConnection.signature;
    }, now: () => DateTime.utc(2026, 11, 2));
    final result = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(requests.map((r) => r.url.path), [
      '/fapi/v3/time',
      '/fapi/v3/positionRisk',
      '/fapi/v3/exchangeInfo',
    ]);
    final read = requests[1];
    expect(read.url.queryParameters['nonce'], '1793620800123000');
    expect(read.url.queryParameters['user'], accountAddress);
    expect(read.url.queryParameters['signer'], accountAddress);
    expect(read.url.queryParameters.containsKey('symbol'), false);
    expect(read.url.queryParameters['signature'], TestWalletConnection.signature);
    expect((signed.single['message']! as Map)['msg'], read.url.query.split('&signature=').first);
    expect((signed.single['domain']! as Map)['chainId'], 1666);
    expect(result.positions.single.units?.base, 'BTC');
    expect(result.receivedAt, DateTime.utc(2026, 11, 2));
  });

  test(
    'loads metadata even for empty baseline; metadata failure retains signed position risk',
    () async {
      for (final empty in [true, false]) {
        var metadata = 0;
        final service = AsterAccountService(
          client: MockClient((request) async {
            if (request.url.path == '/fapi/v3/time') {
              return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
            }
            if (request.url.path == '/fapi/v3/exchangeInfo') {
              metadata++;
              return http.Response('offline', 503);
            }
            return http.Response(jsonEncode(empty ? <Object?>[] : [positionRiskRow()]), 200);
          }),
        );
        final repository = SignedPositionRiskRepository(
          service,
          ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
        );
        final result = await repository.read(
          address: accountAddress,
          isCurrent: () => true,
          onStep: (_) {},
        );
        expect(result.positions.length, empty ? 0 : 1);
        expect(result.positions.isEmpty ? null : result.positions.single.units, null);
        expect(metadata, 1);
        service.close();
      }
    },
  );

  test('wallet refusal and identity change before send do not reach private API', () async {
    for (final rejected in [true, false]) {
      var current = true;
      var reads = 0;
      final service = AsterAccountService(
        client: MockClient((request) async {
          if (request.url.path == '/fapi/v3/positionRisk') reads++;
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }),
      );
      final repository = SignedPositionRiskRepository(service, ({
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

  test('malformed signed risk data fails without fetching metadata', () async {
    var metadata = 0;
    final service = AsterAccountService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/time')) {
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }
        if (request.url.path.endsWith('/exchangeInfo')) metadata++;
        return http.Response(jsonEncode([positionRiskRow()..['markPrice'] = 'NaN']), 200);
      }),
    );
    addTearDown(service.close);
    final repository = SignedPositionRiskRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    await expectLater(
      repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
      throwsA(failure('accountDataInvalid')),
    );
    expect(metadata, 0);
  });

  test('wallet change while public metadata is loading discards signed risk snapshot', () async {
    var current = true;
    final metadataStarted = Completer<void>();
    final gate = Completer<http.Response>();
    final service = AsterAccountService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/time')) {
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }
        if (request.url.path.endsWith('/exchangeInfo')) {
          metadataStarted.complete();
          return gate.future;
        }
        return http.Response(jsonEncode([positionRiskRow()]), 200);
      }),
    );
    addTearDown(service.close);
    final repository = SignedPositionRiskRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final pending = repository.read(
      address: accountAddress,
      isCurrent: () => current,
      onStep: (_) {},
    );
    await metadataStarted.future;
    current = false;
    gate.complete(http.Response(jsonEncode(contractPayload()), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });

  test('late signed position response after identity change is discarded', () async {
    var current = true;
    final gate = Completer<http.Response>();
    final service = AsterAccountService(
      client: MockClient(
        (request) async => request.url.path.endsWith('/time')
            ? http.Response(jsonEncode({'serverTime': 1793620800123}), 200)
            : gate.future,
      ),
    );
    addTearDown(service.close);
    final repository = SignedPositionRiskRepository(
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
    gate.complete(http.Response(jsonEncode([positionRiskRow()]), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });
}

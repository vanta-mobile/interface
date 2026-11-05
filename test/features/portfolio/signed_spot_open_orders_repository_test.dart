import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_spot_open_orders_repository.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/spot_open_orders.dart';
import '../../support/wallet_connection.dart';

void main() {
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test('GET all open Spot orders signs exact bytes and loads Spot units', () async {
    final requests = <http.Request>[];
    final signed = <Map<String, Object?>>[];
    final service = AsterSpotService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        expect(request.url.host, 'sapi.asterdex.com');
        return http.Response(
          jsonEncode(switch (request.url.path) {
            '/api/v3/time' => {'serverTime': 1793620800123},
            '/api/v3/exchangeInfo' => {
              'symbols': [
                {'symbol': 'BTCUSDT', 'baseAsset': 'BTC', 'quoteAsset': 'USDT'},
              ],
            },
            '/api/v3/openOrders' => [spotOpenOrderPayload()],
            _ => throw StateError('unexpected path'),
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final repository = SignedSpotOpenOrdersRepository(service, ({
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
      '/api/v3/time',
      '/api/v3/openOrders',
      '/api/v3/exchangeInfo',
    ]);
    final read = requests[1];
    expect(read.url.queryParameters['nonce'], '1793620800123000');
    expect(read.url.queryParameters['user'], accountAddress);
    expect(read.url.queryParameters['signer'], accountAddress);
    expect(read.url.queryParameters.containsKey('symbol'), false);
    expect(read.url.queryParameters['signature'], TestWalletConnection.signature);
    expect((signed.single['message']! as Map)['msg'], read.url.query.split('&signature=').first);
    expect((signed.single['domain']! as Map)['chainId'], 1666);
    expect(result.orders.single.units?.base, 'BTC');
    expect(result.receivedAt, DateTime.utc(2026, 11, 2));
  });

  test('empty success skips metadata; metadata failure retains signed orders', () async {
    for (final empty in [true, false]) {
      var metadata = 0;
      final service = AsterSpotService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v3/time') {
            return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
          }
          if (request.url.path == '/api/v3/exchangeInfo') {
            metadata++;
            return http.Response('offline', 503);
          }
          return http.Response(jsonEncode(empty ? <Object?>[] : [spotOpenOrderPayload()]), 200);
        }),
      );
      final repository = SignedSpotOpenOrdersRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      final result = await repository.read(
        address: accountAddress,
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.orders.length, empty ? 0 : 1);
      expect(result.orders.isEmpty ? null : result.orders.single.units, null);
      expect(metadata, empty ? 0 : 1);
      service.close();
    }
  });

  test('wallet refusal and identity change before send do not reach private API', () async {
    for (final rejected in [true, false]) {
      var current = true;
      var reads = 0;
      final service = AsterSpotService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v3/openOrders') reads++;
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }),
      );
      final repository = SignedSpotOpenOrdersRepository(service, ({
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

  test('late signed order response after identity change is discarded', () async {
    var current = true;
    final gate = Completer<http.Response>();
    final service = AsterSpotService(
      client: MockClient(
        (request) async => request.url.path.endsWith('/time')
            ? http.Response(jsonEncode({'serverTime': 1793620800123}), 200)
            : gate.future,
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotOpenOrdersRepository(
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
    gate.complete(http.Response(jsonEncode([spotOpenOrderPayload()]), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });
  for (final code in [302, 403, 429, 503]) {
    test('Spot HTTP $code is safe failure and never retried', () async {
      var reads = 0;
      final service = AsterSpotService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/time')) {
            return http.Response('{"serverTime":1793779200000}', 200);
          }
          reads++;
          return http.Response('{"msg":"private transport detail"}', code);
        }),
      );
      addTearDown(service.close);
      final repository = SignedSpotOpenOrdersRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(reads, 1);
    });
  }
  test('malformed payload cannot become an empty Spot account', () async {
    final service = AsterSpotService(
      client: MockClient(
        (r) async => http.Response(
          r.url.path.endsWith('/time') ? '{"serverTime":1793779200000}' : '{}',
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotOpenOrdersRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    await expectLater(
      repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
      throwsA(failure('accountDataInvalid')),
    );
  });
  test('scope loss during public units load discards old Spot account', () async {
    var current = true;
    final service = AsterSpotService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/time')) return http.Response('{"serverTime":1793779200000}', 200);
        if (r.url.path.endsWith('/exchangeInfo')) {
          current = false;
          return http.Response('{"symbols":[]}', 200);
        }
        return http.Response(jsonEncode([spotOpenOrderPayload()]), 200);
      }),
    );
    addTearDown(service.close);
    final repository = SignedSpotOpenOrdersRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    await expectLater(
      repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
      throwsA(failure('authWalletChanged')),
    );
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_open_orders_repository.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/wallet_connection.dart';

void main() {
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test('GET all open futures orders signs exact bytes and loads contract units', () async {
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
            '/fapi/v3/openOrders' => [openOrder()],
            _ => throw StateError('unexpected path'),
          }),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final repository = SignedOpenOrdersRepository(service, ({
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
      '/fapi/v3/openOrders',
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
    expect(result.orders.single.units?.base, 'BTC');
    expect(result.receivedAt, DateTime.utc(2026, 11, 2));
  });

  test('empty success skips metadata; metadata failure retains signed orders', () async {
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
          return http.Response(jsonEncode(empty ? <Object?>[] : [openOrder()]), 200);
        }),
      );
      final repository = SignedOpenOrdersRepository(
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
      final service = AsterAccountService(
        client: MockClient((request) async {
          if (request.url.path == '/fapi/v3/openOrders') reads++;
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }),
      );
      final repository = SignedOpenOrdersRepository(service, ({
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
    final service = AsterAccountService(
      client: MockClient(
        (request) async => request.url.path.endsWith('/time')
            ? http.Response(jsonEncode({'serverTime': 1793620800123}), 200)
            : gate.future,
      ),
    );
    addTearDown(service.close);
    final repository = SignedOpenOrdersRepository(
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
    gate.complete(http.Response(jsonEncode([openOrder()]), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });
}

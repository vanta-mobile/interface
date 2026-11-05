import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_spot_history_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';

import '../../support/aster_account.dart';
import '../../support/spot_history.dart';
import '../../support/wallet_connection.dart';

void main() {
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'safe key', key);
  SpotHistoryQuery query(SpotHistoryKind kind, {String scope = ''}) =>
      SpotHistoryQuery(kind: kind, window: historyWindow, scope: scope);
  Future<String> sign({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async => TestWalletConnection.signature;

  test('three histories use exact Spot endpoints, same wallet and query bytes with shared unique nonces', () async {
    final requests = <http.Request>[];
    final signatures = <Map<String, Object?>>[];
    final service = AsterSpotService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'sapi.asterdex.com');
        expect(request.method, 'GET');
        expect(request.followRedirects, false);
        final payload = switch (request.url.path) {
          '/api/v3/time' => {'serverTime': 1793620800123},
          '/api/v3/exchangeInfo' => spotSymbols(),
          '/api/v3/allOrders' => [spotOrderRow()],
          '/api/v3/userTrades' => [spotTradeRow()],
          '/api/v3/transactionHistory' => [spotTransactionRow()],
          _ => throw StateError('wrong endpoint'),
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    addTearDown(service.close);
    final repository = SignedSpotHistoryRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        signatures.add(typedData);
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => historyNow,
    );
    for (final kind in SpotHistoryKind.values) {
      final result = await repository.read(
        address: accountAddress,
        query: query(kind, scope: kind == SpotHistoryKind.transactions ? 'ASTER' : 'BNBUSDT'),
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.records.length, 1);
      expect(result.receivedAt, historyNow);
    }
    final privateRequests = requests
        .where((r) => r.url.queryParameters.containsKey('signature'))
        .toList();
    expect(privateRequests.map((r) => r.url.path), [
      '/api/v3/allOrders',
      '/api/v3/userTrades',
      '/api/v3/transactionHistory',
    ]);
    expect(requests.where((r) => r.url.path == '/api/v3/exchangeInfo').length, 1);
    for (var i = 0; i < 3; i++) {
      final params = privateRequests[i].url.queryParameters;
      expect(params.keys.toSet(), {
        i == 2 ? 'asset' : 'symbol',
        'startTime',
        'endTime',
        'limit',
        'nonce',
        'user',
        'signer',
        'signature',
      });
      expect(params['startTime'], '${historyWindow.start}');
      expect(params['endTime'], '${historyWindow.end}');
      expect(params['limit'], '1000');
      expect(params['nonce'], '${1793620800123000 + i}');
      expect(params['user'], accountAddress);
      expect(params['signer'], accountAddress);
      expect((signatures[i]['domain']! as Map)['chainId'], 1666);
      expect(
        (signatures[i]['message']! as Map)['msg'],
        privateRequests[i].url.query.split('&signature=').first,
      );
      expect(params, isNot(contains('orderId')));
      expect(params, isNot(contains('fromId')));
    }
  });

  test(
    'invalid scope or request longer than seven days is rejected before any HTTP or signature',
    () async {
      var calls = 0;
      final service = AsterSpotService(
        client: MockClient((_) async {
          calls++;
          throw StateError('must not send');
        }),
      );
      addTearDown(service.close);
      final repository = SignedSpotHistoryRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        calls++;
        return TestWalletConnection.signature;
      }, nonces: AsterReadNonces());
      for (final q in [
        query(SpotHistoryKind.orders, scope: 'BNB USDT'),
        SpotHistoryQuery(
          kind: SpotHistoryKind.trades,
          window: HistoryWindow.recent(historyNow, const Duration(days: 8)),
        ),
      ]) {
        await expectLater(
          repository.read(address: accountAddress, query: q, isCurrent: () => true, onStep: (_) {}),
          throwsA(failure(q.validScope ? 'historyInvalidWindow' : 'historyInvalidScope')),
        );
      }
      expect(calls, 0);
    },
  );

  test('metadata outage keeps valid history with units explicitly unavailable', () async {
    final service = AsterSpotService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/time')
                ? {'serverTime': 1793620800123}
                : request.url.path.endsWith('exchangeInfo')
                ? {'msg': 'raw unavailable'}
                : [spotTradeRow()],
          ),
          request.url.path.endsWith('exchangeInfo') ? 503 : 200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotHistoryRepository(service, sign, nonces: AsterReadNonces());
    final result = await repository.read(
      address: accountAddress,
      query: query(SpotHistoryKind.trades),
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(result.records.length, 1);
    expect(result.unitsUnavailable, true);
    expect((result.records.single as SpotTradeRecord).commissionAsset, 'BNB');
  });

  test('refusal or changed signing identity sends no private request or metadata query', () async {
    for (final refused in [true, false]) {
      final requests = <http.Request>[];
      var current = true;
      final service = AsterSpotService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"serverTime":1793620800123}', 200);
        }),
      );
      final repository = SignedSpotHistoryRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        if (refused) throw const AuthFailure('authWalletRejected');
        current = false;
        return TestWalletConnection.signature;
      }, nonces: AsterReadNonces());
      await expectLater(
        repository.read(
          address: accountAddress,
          query: query(SpotHistoryKind.orders),
          isCurrent: () => current,
          onStep: (_) {},
        ),
        throwsA(failure(refused ? 'authWalletRejected' : 'authWalletChanged')),
      );
      expect(requests.single.url.path, '/api/v3/time');
      service.close();
    }
  });

  test('wrong-symbol or malformed response yields safe error rather than empty history', () async {
    Object? response = [spotOrderRow(symbol: 'BTCUSDT')];
    final service = AsterSpotService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/time')
                ? {'serverTime': 1793620800123}
                : request.url.path.endsWith('exchangeInfo')
                ? spotSymbols()
                : response,
          ),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotHistoryRepository(service, sign, nonces: AsterReadNonces());
    for (final payload in [
      response,
      {'rows': <Object?>[]},
      [spotOrderRow()..['price'] = 'NaN'],
    ]) {
      response = payload;
      await expectLater(
        repository.read(
          address: accountAddress,
          query: query(SpotHistoryKind.orders, scope: 'BNBUSDT'),
          isCurrent: () => true,
          onStep: (_) {},
        ),
        throwsA(failure('accountDataInvalid')),
      );
    }
  });

  test('UTF-8 ledger asset scope, huge identifier and signed delta retain precision', () async {
    final service = AsterSpotService(
      client: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(
              request.url.path.endsWith('/time')
                  ? {'serverTime': 1793620800123}
                  : [spotTransactionRow(asset: '币安人生', id: '99999999999999999999999999999')],
            ),
          ),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedSpotHistoryRepository(service, sign, nonces: AsterReadNonces());
    final result = await repository.read(
      address: accountAddress,
      query: query(SpotHistoryKind.transactions, scope: '币安人生'),
      isCurrent: () => true,
      onStep: (_) {},
    );
    final row = result.records.single as SpotTransactionRecord;
    expect(row.asset, '币安人生');
    expect(row.transactionId, '99999999999999999999999999999');
    expect(row.delta.toString(), '-500.000000000000000001');
  });

  test('wallet change during optional metadata request still discards signed history', () async {
    var current = true;
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    final service = AsterSpotService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('exchangeInfo')) {
          started.complete();
          return gate.future;
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/time') ? {'serverTime': 1793620800123} : [spotOrderRow()],
          ),
          200,
        );
      }),
    );
    addTearDown(service.close);
    final repository = SignedSpotHistoryRepository(service, sign, nonces: AsterReadNonces());
    final pending = repository.read(
      address: accountAddress,
      query: query(SpotHistoryKind.orders),
      isCurrent: () => current,
      onStep: (_) {},
    );
    await started.future;
    current = false;
    gate.complete(http.Response(jsonEncode(spotSymbols()), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
  });

  test('transport permissions and timeout map to safe failures without replay', () async {
    for (final timeout in [true, false]) {
      var privateCalls = 0;
      final service = AsterSpotService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/time')) {
            return http.Response('{"serverTime":1793620800123}', 200);
          }
          privateCalls++;
          if (timeout) throw TimeoutException('raw URL/signature must not escape');
          return http.Response('{"code":-2015,"msg":"raw token detail"}', 403);
        }),
      );
      final repository = SignedSpotHistoryRepository(service, sign, nonces: AsterReadNonces());
      await expectLater(
        repository.read(
          address: accountAddress,
          query: query(SpotHistoryKind.transactions),
          isCurrent: () => true,
          onStep: (_) {},
        ),
        throwsA(failure(timeout ? 'accountNetwork' : 'accountPermissionRequired')),
      );
      expect(privateCalls, 1);
      service.close();
    }
  });
}

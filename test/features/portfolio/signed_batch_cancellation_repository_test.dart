import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_batch_cancellation_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedBatchCancellationRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? queryPayload;
  late int queryStatus;
  late bool deleteTimeout, current;
  late int refusedSignature;
  Completer<http.Response>? deleteGate;

  setUp(() {
    requests = [];
    messages = [];
    queryPayload = [];
    queryStatus = 200;
    deleteTimeout = false;
    current = true;
    refusedSignature = 0;
    deleteGate = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, false);
        expect(request.url.host, 'fapi.asterdex.com');
        if (request.url.path.endsWith('/time')) {
          expect(request.method, 'GET');
          return http.Response('{"serverTime":1793620800123}', 200);
        }
        if (request.method == 'DELETE') {
          expect(request.url.path, '/fapi/v3/allOpenOrders');
          if (deleteTimeout) throw TimeoutException('raw error');
          return deleteGate?.future ?? http.Response('{"code":"200","msg":"done"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/fapi/v3/openOrders');
        return http.Response(jsonEncode(queryPayload), queryStatus);
      }),
    );
    repository = SignedBatchCancellationRepository(service, ({
      required expectedAddress,
      required typedData,
    }) async {
      expect(expectedAddress, accountAddress);
      expect((typedData['domain']! as Map)['chainId'], 1666);
      messages.add((typedData['message']! as Map)['msg']! as String);
      if (messages.length == refusedSignature) throw const AuthFailure('authWalletRejected');
      return TestWalletConnection.signature;
    }, nonces: AsterReadNonces());
  });
  tearDown(() => service.close());

  test('symbol-bound DELETE and GET sign exact query bytes with distinct nonces', () async {
    final result = await repository.cancelSymbol(
      address: accountAddress,
      symbol: 'BTCUSDT',
      originalOrders: openOrdersFixture().orders,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.submitted, true);
    expect(result.snapshot!.orders, isEmpty);
    expect(result.needsRecheck, false);
    expect(requests.map((r) => r.method), ['GET', 'DELETE', 'GET', 'GET']);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    for (var i = 0; i < signed.length; i++) {
      final query = signed[i].url.queryParameters;
      expect(query.keys.toSet(), {'symbol', 'nonce', 'user', 'signer', 'signature'});
      expect(query['symbol'], 'BTCUSDT');
      expect(query['user'], accountAddress);
      expect(query['signer'], accountAddress);
      expect(query['signature'], TestWalletConnection.signature);
      expect(signed[i].url.query.split('&signature=').first, messages[i]);
      expect(signed[i].body, isEmpty);
    }
    expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 2);
  });

  test('success acknowledgement does not hide remaining or newly created orders', () async {
    queryPayload = [
      openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.123456789012345678'),
      openOrder(id: 123),
    ];
    final result = await repository.cancelSymbol(
      address: accountAddress,
      symbol: 'BTCUSDT',
      originalOrders: openOrdersFixture().orders,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.snapshot!.orders.length, 2);
    expect(
      result.snapshot!.orders.firstWhere((o) => o.orderId == '1917641').executedQty.toString(),
      '0.123456789012345678',
    );
    expect(result.snapshot!.orders.first.units?.base, 'BTC');
  });

  test(
    'timeout is reconciled once without replaying DELETE; uncertain result is retained',
    () async {
      deleteTimeout = true;
      queryStatus = 503;
      final result = await repository.cancelSymbol(
        address: accountAddress,
        symbol: 'BTCUSDT',
        originalOrders: openOrdersFixture().orders,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.submitted, true);
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'accountReadFailed');
      queryStatus = 200;
      final checked = await repository.recheckSymbol(
        address: accountAddress,
        symbol: 'BTCUSDT',
        originalOrders: openOrdersFixture().orders,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(checked.snapshot!.orders, isEmpty);
      expect(requests.where((r) => r.method == 'DELETE').length, 1);
    },
  );

  test(
    'first signature refusal sends no private request; query refusal keeps outcome unknown',
    () async {
      refusedSignature = 1;
      final refused = await repository.cancelSymbol(
        address: accountAddress,
        symbol: 'BTCUSDT',
        originalOrders: [],
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(refused.submitted, false);
      expect(refused.failure?.key, 'authWalletRejected');
      expect(requests.where((r) => !r.url.path.endsWith('/time')), isEmpty);
      messages.clear();
      refusedSignature = 2;
      final uncertain = await repository.cancelSymbol(
        address: accountAddress,
        symbol: 'BTCUSDT',
        originalOrders: [],
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(uncertain.needsRecheck, true);
      expect(uncertain.failure?.key, 'authWalletRejected');
    },
  );

  test('foreign symbol rows, malformed payload and invalid amounts cannot clear a scope', () async {
    for (final payload in [
      [openOrder(symbol: 'ETHUSDT')],
      [openOrder(symbol: 'ETHUSDT', status: 'CANCELED')],
      {'orders': <Object?>[]},
      [openOrder(executedQty: '900')],
    ]) {
      queryPayload = payload;
      final result = await repository.recheckSymbol(
        address: accountAddress,
        symbol: 'BTCUSDT',
        originalOrders: [],
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'accountDataInvalid');
    }
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
  });

  test('in-flight DELETE followed by wallet change cannot trigger another signature', () async {
    deleteGate = Completer<http.Response>();
    final pending = repository.cancelSymbol(
      address: accountAddress,
      symbol: 'BTCUSDT',
      originalOrders: [],
      isCurrent: () => current,
      onStep: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    deleteGate!.complete(http.Response('{}', 200));
    await expectLater(
      pending,
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(messages.length, 1);
  });

  test('separate symbols share a monotonic nonce allocator and never use a Spot path', () async {
    for (final symbol in ['BTCUSDT', 'ETHUSDT']) {
      await repository.cancelSymbol(
        address: accountAddress,
        symbol: symbol,
        originalOrders: [],
        isCurrent: () => current,
        onStep: (_) {},
      );
    }
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 4);
    expect(signed.map((r) => r.url.queryParameters['symbol']), [
      'BTCUSDT',
      'BTCUSDT',
      'ETHUSDT',
      'ETHUSDT',
    ]);
    expect(signed.every((r) => r.url.path.startsWith('/fapi/v3/')), true);
  });

  test('invalid symbol is rejected before signature or HTTP dispatch', () async {
    final result = await repository.cancelSymbol(
      address: accountAddress,
      symbol: 'BTCUSDT&symbol=ETHUSDT',
      originalOrders: [],
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.submitted, false);
    expect(result.failure?.key, 'accountDataInvalid');
    expect(requests, isEmpty);
    expect(messages, isEmpty);
  });
}

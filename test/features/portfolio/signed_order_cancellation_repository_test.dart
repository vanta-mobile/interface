import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_order_cancellation_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/wallet_connection.dart';

void main() {
  final order = openOrdersFixture().orders.firstWhere((o) => o.symbol == 'BTCUSDT');
  late List<http.Request> requests;
  late List<String> messages;
  late AsterAccountService service;
  late SignedOrderCancellationRepository repository;
  late Object? queryPayload;
  late int cancelStatus;
  late int queryStatus;
  late int refusedSignature;
  late bool current;
  Completer<http.Response>? deleteGate;

  setUp(() {
    requests = [];
    messages = [];
    queryPayload = openOrder(status: 'CANCELED');
    cancelStatus = queryStatus = 200;
    refusedSignature = 0;
    current = true;
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
        expect(request.url.path, '/fapi/v3/order');
        if (request.method == 'DELETE') {
          return deleteGate?.future ??
              http.Response(jsonEncode(openOrder(status: 'CANCELED')), cancelStatus);
        }
        expect(request.method, 'GET');
        return http.Response(jsonEncode(queryPayload), queryStatus);
      }),
    );
    repository = SignedOrderCancellationRepository(service, ({
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

  test(
    'DELETE then GET sign exact symbol/id bytes with distinct nonces and the same EOA',
    () async {
      final result = await repository.cancel(
        address: accountAddress,
        order: order,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.resolution?.status, 'CANCELED');
      expect(result.needsRecheck, false);
      expect(requests.map((r) => r.method), ['GET', 'DELETE', 'GET', 'GET']);
      final signed = requests.where((r) => r.url.path.endsWith('/order')).toList();
      for (var i = 0; i < signed.length; i++) {
        final query = signed[i].url.queryParameters;
        expect(query['symbol'], 'BTCUSDT');
        expect(query['orderId'], '1917641');
        expect(query['user'], accountAddress);
        expect(query['signer'], accountAddress);
        expect(query['signature'], TestWalletConnection.signature);
        expect(query.keys.toSet(), {'symbol', 'orderId', 'user', 'signer', 'nonce', 'signature'});
        expect(signed[i].url.query.split('&signature=').first, messages[i]);
        expect(signed[i].body, isEmpty);
      }
      expect(signed[0].url.queryParameters['nonce'], '1793620800123000');
      expect(signed[1].url.queryParameters['nonce'], '1793620800123001');
    },
  );

  test('final filled order takes precedence over a cancellation acknowledgement', () async {
    queryPayload = openOrder(status: 'FILLED', executedQty: '0.40');
    final result = await repository.cancel(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.resolution?.status, 'FILLED');
    expect(result.resolution?.openOrder, null);
  });

  test('failed DELETE is never replayed; final query can confirm the outcome', () async {
    cancelStatus = 503;
    final result = await repository.cancel(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.resolution?.status, 'CANCELED');
    expect(result.failure, null);
    expect(requests.where((r) => r.method == 'DELETE').length, 1);
  });

  test('timeout plus failed reconciliation stays unknown; recheck only sends GET', () async {
    deleteGate = Completer<http.Response>();
    queryStatus = 503;
    final pending = repository.cancel(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    deleteGate!.completeError(TimeoutException('raw sensitive error'));
    final result = await pending;
    expect(result.needsRecheck, true);
    expect(result.failure?.key, 'accountReadFailed');
    queryStatus = 200;
    final checked = await repository.recheck(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(checked.resolution?.status, 'CANCELED');
    expect(requests.where((r) => r.method == 'DELETE').length, 1);
  });

  test(
    'refused first signature sends no cancellation; refused query retains uncertainty',
    () async {
      refusedSignature = 1;
      await expectLater(
        repository.cancel(
          address: accountAddress,
          order: order,
          isCurrent: () => current,
          onStep: (_) {},
        ),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletRejected')),
      );
      expect(requests.where((r) => r.url.path.endsWith('/order')), isEmpty);
      messages.clear();
      refusedSignature = 2;
      final result = await repository.cancel(
        address: accountAddress,
        order: order,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'authWalletRejected');
      expect(requests.where((r) => r.method == 'DELETE').length, 1);
    },
  );

  test(
    'wrong symbol/id, unknown status and invalid active amounts never confirm cancellation',
    () async {
      for (final payload in [
        openOrder(symbol: 'ETHUSDT', status: 'CANCELED'),
        openOrder(id: 123, status: 'CANCELED'),
        openOrder(status: 'UNKNOWN'),
        openOrder(status: 'PARTIALLY_FILLED', executedQty: '99'),
      ]) {
        queryPayload = payload;
        final result = await repository.recheck(
          address: accountAddress,
          order: order,
          isCurrent: () => current,
          onStep: (_) {},
        );
        expect(result.needsRecheck, true);
        expect(result.failure?.key, 'accountDataInvalid');
      }
    },
  );

  test('still-open query preserves the latest partial fill with exact decimal units', () async {
    queryPayload = openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.123456789012345678');
    final result = await repository.cancel(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.resolution?.terminal, false);
    expect(result.resolution?.openOrder?.executedQty.toString(), '0.123456789012345678');
    expect(result.resolution?.openOrder?.units?.base, 'BTC');
  });

  test('identity changes while DELETE is in flight prevent follow-up signing', () async {
    deleteGate = Completer<http.Response>();
    final pending = repository.cancel(
      address: accountAddress,
      order: order,
      isCurrent: () => current,
      onStep: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    deleteGate!.complete(http.Response('{}', 200));
    await expectLater(
      pending,
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletChanged')),
    );
    expect(messages.length, 1);
  });

  test('extra parameters cannot overwrite account identity or nonce', () async {
    final request = SignedAccountRequest(
      serverTime: service.serverTime,
      send: service.queryOrder,
      sign: ({required expectedAddress, required typedData}) async =>
          TestWalletConnection.signature,
    );
    for (final key in ['user', 'signer', 'nonce', 'signature']) {
      await expectLater(
        request.read(
          address: accountAddress,
          isCurrent: () => true,
          onStep: (_) {},
          parameters: {key: 'overwrite'},
        ),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'accountDataInvalid')),
      );
    }
    expect(requests, isEmpty);
  });
}

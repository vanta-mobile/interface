import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_position_margin_mode_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import '../../support/aster_account.dart';
import '../../support/position_margin_mode.dart';
import '../../support/wallet_connection.dart';
import '../../support/aster_open_orders.dart';

void main() {
  late AsterAccountService service;
  late SignedPositionMarginModeRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? positions, orders;
  late int postStatus, getStatus, refuse;
  late String postBody;
  late bool current, canSubmit;
  late DateTime clock;
  late bool slowSecondSignature;
  Completer<String>? signatureGate;
  Completer<http.Response>? postGate;
  final intent = MarginModeIntent(
    context: marginModeContext(),
    target: PositionMarginMode.isolated,
    revision: 0,
  );
  setUp(() {
    requests = [];
    messages = [];
    positions = marginModeRows(mode: 'isolated');
    orders = <Object?>[];
    postStatus = getStatus = 200;
    postBody = '{}';
    refuse = 0;
    current = canSubmit = true;
    clock = marginModeClock;
    slowSecondSignature = false;
    signatureGate = null;
    postGate = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, false);
        expect(request.url.host, 'fapi.asterdex.com');
        if (request.url.path.endsWith('/time')) {
          return http.Response('{"serverTime":1793707200000}', 200);
        }
        if (request.url.path.endsWith('/openOrders')) {
          return http.Response(jsonEncode(orders), getStatus);
        }
        if (request.method == 'POST') {
          expect(request.url.path, '/fapi/v3/marginType');
          return postGate?.future ?? http.Response(postBody, postStatus);
        }
        expect(request.url.path, '/fapi/v3/positionRisk');
        return http.Response(jsonEncode(positions), getStatus);
      }),
    );
    repository = SignedPositionMarginModeRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (slowSecondSignature && messages.length == 2) {
          clock = clock.add(const Duration(seconds: 31));
        }
        if (messages.length == refuse) throw const AuthFailure('authWalletRejected');
        return signatureGate?.future ?? TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => clock,
    );
  });
  tearDown(() => service.close());
  Future<MarginModeResult> change() => repository.change(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSubmit,
    onStep: (_) {},
  );
  Future<MarginModeResult> recheck() =>
      repository.recheck(intent: intent, isCurrent: () => current, onStep: (_) {});

  test(
    'signed context reads recommended open orders and zero-sized position configuration',
    () async {
      final result = await repository.read(
        address: accountAddress,
        symbol: 'BTCUSDT',
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.current, PositionMarginMode.isolated);
      expect(result.blocked, false);
      expect(result.receivedAt, marginModeClock);
      final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
      expect(signed.map((r) => r.url.path), ['/fapi/v3/positionRisk', '/fapi/v3/openOrders']);
      for (var i = 0; i < signed.length; i++) {
        expect(signed[i].method, 'GET');
        expect(signed[i].url.query.split('&signature=').first, messages[i]);
        expect(signed[i].url.queryParameters['symbol'], 'BTCUSDT');
      }
    },
  );
  test('POST exact signed body then fresh signed GET; same EOA with distinct nonces', () async {
    final result = await change();
    expect(result.observed, PositionMarginMode.isolated);
    expect(result.checkedAt, marginModeClock);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.method), ['POST', 'GET']);
    final post = signed.first;
    expect(post.url.query, isEmpty);
    expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
    expect(post.body.split('&signature=').first, messages.first);
    expect(post.body, endsWith('&signature=${TestWalletConnection.signature}'));
    final parameters = Uri.splitQueryString(post.body);
    expect(parameters['marginType'], 'ISOLATED');
    expect(parameters['symbol'], 'BTCUSDT');
    expect(parameters['user'], accountAddress);
    expect(parameters['signer'], accountAddress);
    expect(parameters.keys.toSet(), {
      'symbol',
      'marginType',
      'nonce',
      'user',
      'signer',
      'signature',
    });
    expect(signed.last.url.query.split('&signature=').first, messages.last);
    expect(parameters['nonce'], isNot(signed.last.url.queryParameters['nonce']));
  });
  test('acknowledgement alone never confirms the target; current query wins', () async {
    positions = marginModeRows(mode: 'cross', hedge: true);
    expect((await change()).observed, PositionMarginMode.cross);
  });
  test(
    'failed POST followed by successful query can verify the target, never replay POST',
    () async {
      postStatus = 503;
      final result = await change();
      expect(result.observed, PositionMarginMode.isolated);
      expect(result.failure, null);
      expect(requests.where((r) => r.method == 'POST').length, 1);
    },
  );
  test('timeout and failed query preserve uncertainty; recheck sends only signed GET', () async {
    postGate = Completer<http.Response>();
    getStatus = 503;
    final pending = change();
    await Future<void>.delayed(Duration.zero);
    postGate!.completeError(TimeoutException('sensitive payload'));
    final result = await pending;
    expect(result.needsRecheck, true);
    getStatus = 200;
    expect((await recheck()).observed, PositionMarginMode.isolated);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test(
    'refused first signature sends no POST; refused verification keeps unknown outcome',
    () async {
      refuse = 1;
      await expectLater(
        change(),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletRejected')),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      messages.clear();
      refuse = 2;
      final result = await change();
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'authWalletRejected');
    },
  );
  test('late wallet approval after context expiry cannot send a write', () async {
    signatureGate = Completer<String>();
    final pending = change();
    await Future<void>.delayed(Duration.zero);
    canSubmit = false;
    signatureGate!.complete(TestWalletConnection.signature);
    await expectLater(
      pending,
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginModeContextExpired')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('wallet switch during POST prevents verification signature', () async {
    postGate = Completer<http.Response>();
    final pending = change();
    await Future<void>.delayed(Duration.zero);
    current = false;
    postGate!.complete(http.Response('{}', 200));
    await expectLater(
      pending,
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletChanged')),
    );
    expect(messages.length, 1);
  });
  test('mismatched symbols and conflicting hedge configurations cannot verify result', () async {
    for (final data in [
      marginModeRows(symbol: 'ETHUSDT'),
      <Object?>[],
      [marginModeRows(hedge: true).first, marginModeRows(hedge: true, mode: 'isolated').last],
    ]) {
      positions = data;
      final result = await recheck();
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'accountDataInvalid');
    }
  });
  test('invalid target rejected before time, signing or HTTP', () async {
    await expectLater(
      repository.change(
        intent: MarginModeIntent(
          context: marginModeContext(),
          target: PositionMarginMode.cross,
          revision: 0,
        ),
        isCurrent: () => true,
        canSubmit: () => true,
        onStep: (_) {},
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests, isEmpty);
    expect(messages, isEmpty);
  });

  test(
    'preflight preserves position and same-symbol open order blockers without changing them',
    () async {
      positions = marginModeRows(mode: 'cross', quantity: '0.000000000000000000001');
      orders = [openOrder()];
      final context = await repository.read(
        address: accountAddress,
        symbol: 'BTCUSDT',
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(context.hasPosition, true);
      expect(context.openOrderCount, 1);
      expect(context.blocked, true);
      await expectLater(
        repository.change(
          intent: MarginModeIntent(
            context: context,
            target: PositionMarginMode.isolated,
            revision: 0,
          ),
          isCurrent: () => true,
          canSubmit: () => true,
          onStep: (_) {},
        ),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test('wrong-symbol or malformed open orders cannot certify an empty order scope', () async {
    for (final data in <Object?>[
      [openOrder(symbol: 'ETHUSDT')],
      {},
      [openOrder(origQty: 'bad')],
    ]) {
      orders = data;
      await expectLater(
        repository.read(
          address: accountAddress,
          symbol: 'BTCUSDT',
          isCurrent: () => current,
          onStep: (_) {},
        ),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'accountDataInvalid')),
      );
    }
  });

  test(
    'waiting for the open-order signature does not reset the first configuration read time',
    () async {
      slowSecondSignature = true;
      final result = await repository.read(
        address: accountAddress,
        symbol: 'BTCUSDT',
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.receivedAt, marginModeClock);
      expect(clock.difference(result.receivedAt), const Duration(seconds: 31));
    },
  );

  test(
    'documented margin mode rejections expose concrete safe reasons and preserve error codes',
    () async {
      positions = marginModeRows(mode: 'cross');
      for (final (code, key) in [
        (-4047, 'marginModeOpenOrders'),
        (-4048, 'marginModeHasPosition'),
        (-4046, 'marginModeAlreadySet'),
      ]) {
        postStatus = 400;
        postBody = jsonEncode({'code': code, 'msg': 'raw sensitive response'});
        final result = await change();
        expect(result.observed, PositionMarginMode.cross);
        expect(result.failure?.key, key);
        expect(result.failure?.code, code);
      }
    },
  );
}

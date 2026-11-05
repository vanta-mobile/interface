import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_position_leverage_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';

import '../../support/aster_account.dart';
import '../../support/position_leverage.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedPositionLeverageRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? positions, brackets;
  late int postStatus, getStatus, refuse;
  late String postBody;
  late bool current, canSubmit;
  Completer<String>? signatureGate;
  Completer<http.Response>? postGate;
  final intent = LeverageIntent(context: leverageContext(), target: 20, revision: 0);
  setUp(() {
    requests = [];
    messages = [];
    positions = leverageRows(value: '20');
    brackets = leverageBrackets();
    postStatus = getStatus = 200;
    postBody = '{}';
    refuse = 0;
    current = canSubmit = true;
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
        if (request.url.path.endsWith('/leverageBrackets')) {
          return http.Response(jsonEncode(brackets), getStatus);
        }
        if (request.method == 'POST') {
          expect(request.url.path, '/fapi/v3/leverage');
          return postGate?.future ?? http.Response(postBody, postStatus);
        }
        expect(request.url.path, '/fapi/v3/positionRisk');
        return http.Response(jsonEncode(positions), getStatus);
      }),
    );
    repository = SignedPositionLeverageRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (messages.length == refuse) throw const AuthFailure('authWalletRejected');
        return signatureGate?.future ?? TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => leverageClock,
    );
  });
  tearDown(() => service.close());
  Future<LeverageResult> change() => repository.change(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSubmit,
    onStep: (_) {},
  );
  Future<LeverageResult> recheck() =>
      repository.recheck(intent: intent, isCurrent: () => current, onStep: (_) {});

  test('signed context reads recommended brackets and zero-sized position configuration', () async {
    final result = await repository.read(
      address: accountAddress,
      symbol: 'BTCUSDT',
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.current, 20);
    expect(result.maximum, 100);
    expect(result.receivedAt, leverageClock);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.url.path), ['/fapi/v3/leverageBrackets', '/fapi/v3/positionRisk']);
    for (var i = 0; i < signed.length; i++) {
      expect(signed[i].method, 'GET');
      expect(signed[i].url.query.split('&signature=').first, messages[i]);
      expect(signed[i].url.queryParameters['symbol'], 'BTCUSDT');
    }
  });
  test('POST exact signed body then fresh signed GET; same EOA with distinct nonces', () async {
    final result = await change();
    expect(result.observed, 20);
    expect(result.checkedAt, leverageClock);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.method), ['POST', 'GET']);
    final post = signed.first;
    expect(post.url.query, isEmpty);
    expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
    expect(post.body.split('&signature=').first, messages.first);
    expect(post.body, endsWith('&signature=${TestWalletConnection.signature}'));
    final parameters = Uri.splitQueryString(post.body);
    expect(parameters['leverage'], '20');
    expect(parameters['symbol'], 'BTCUSDT');
    expect(parameters['user'], accountAddress);
    expect(parameters['signer'], accountAddress);
    expect(parameters.keys.toSet(), {'symbol', 'leverage', 'nonce', 'user', 'signer', 'signature'});
    expect(signed.last.url.query.split('&signature=').first, messages.last);
    expect(parameters['nonce'], isNot(signed.last.url.queryParameters['nonce']));
  });
  test('acknowledgement alone never confirms the target; current query wins', () async {
    positions = leverageRows(value: '10', hedge: true);
    expect((await change()).observed, 10);
  });
  test(
    'failed POST followed by successful query can verify the target, never replay POST',
    () async {
      postStatus = 503;
      final result = await change();
      expect(result.observed, 20);
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
    expect((await recheck()).observed, 20);
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
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'leverageContextExpired')),
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
      leverageRows(symbol: 'ETHUSDT'),
      <Object?>[],
      [leverageRows(hedge: true).first, leverageRows(hedge: true, value: '20').last],
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
        intent: LeverageIntent(context: leverageContext(), target: 101, revision: 0),
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
    'documented leverage rejections expose concrete safe reasons and preserve error codes',
    () async {
      positions = leverageRows(value: '10');
      for (final (code, key) in [
        (-2027, 'leverageExposureLimit'),
        (-2028, 'leverageMarginInsufficient'),
        (-4028, 'leverageNotAllowed'),
      ]) {
        postStatus = 400;
        postBody = jsonEncode({'code': code, 'msg': 'raw sensitive response'});
        final result = await change();
        expect(result.observed, 10);
        expect(result.failure?.key, key);
        expect(result.failure?.code, code);
      }
    },
  );
}

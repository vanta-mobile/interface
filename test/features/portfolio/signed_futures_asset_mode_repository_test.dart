import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_futures_asset_mode_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedFuturesAssetModeRepository repository;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? positions, mode;
  late int postStatus, getStatus, refuse;
  late String postBody;
  late bool current, canSubmit;
  late DateTime clock;
  late bool slowSecondSignature;
  Completer<String>? signatureGate;
  Completer<http.Response>? postGate;
  final intent = AssetModeIntent(
    context: assetModeContext(),
    target: FuturesAssetMode.multi,
    revision: 0,
  );
  setUp(() {
    requests = [];
    messages = [];
    positions = assetModeRows();
    mode = {'multiAssetsMargin': true};
    postStatus = getStatus = 200;
    postBody = '{}';
    refuse = 0;
    current = canSubmit = true;
    clock = assetModeClock;
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
        if (request.method == 'POST') {
          expect(request.url.path, '/fapi/v3/multiAssetsMargin');
          return postGate?.future ?? http.Response(postBody, postStatus);
        }
        if (request.url.path.endsWith('/multiAssetsMargin')) {
          return http.Response(jsonEncode(mode), getStatus);
        }
        if (request.url.path == AsterAccountService.accountPath) {
          return http.Response(jsonEncode(accountPayload()), getStatus);
        }
        expect(request.url.path, '/fapi/v3/positionRisk');
        return http.Response(jsonEncode(positions), getStatus);
      }),
    );
    repository = SignedFuturesAssetModeRepository(
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
  Future<AssetModeResult> change() => repository.change(
    intent: intent,
    isCurrent: () => current,
    canSubmit: () => canSubmit,
    onStep: (_) {},
  );
  Future<AssetModeResult> recheck() =>
      repository.recheck(intent: intent, isCurrent: () => current, onStep: (_) {});

  test('signed context reads asset mode and unfiltered position configuration', () async {
    final result = await repository.read(
      address: accountAddress,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(result.current, FuturesAssetMode.multi);
    expect(result.blocks(FuturesAssetMode.multi), false);
    expect(result.receivedAt, assetModeClock);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.url.path), [
      '/fapi/v3/multiAssetsMargin',
      '/fapi/v3/positionRisk',
      AsterAccountService.accountPath,
    ]);
    for (var i = 0; i < signed.length; i++) {
      expect(signed[i].method, 'GET');
      expect(signed[i].url.query.split('&signature=').first, messages[i]);
      expect(signed[i].url.queryParameters.containsKey('symbol'), false);
    }
  });
  test('POST exact signed body then fresh signed GET; same EOA with distinct nonces', () async {
    final result = await change();
    expect(result.observed, FuturesAssetMode.multi);
    expect(result.checkedAt, assetModeClock);
    final signed = requests.where((r) => !r.url.path.endsWith('/time')).toList();
    expect(signed.map((r) => r.method), ['POST', 'GET']);
    final post = signed.first;
    expect(post.url.query, isEmpty);
    expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
    expect(post.body.split('&signature=').first, messages.first);
    expect(post.body, endsWith('&signature=${TestWalletConnection.signature}'));
    final parameters = Uri.splitQueryString(post.body);
    expect(parameters['multiAssetsMargin'], 'true');
    expect(parameters.containsKey('symbol'), false);
    expect(parameters['user'], accountAddress);
    expect(parameters['signer'], accountAddress);
    expect(parameters.keys.toSet(), {'multiAssetsMargin', 'nonce', 'user', 'signer', 'signature'});
    expect(signed.last.url.query.split('&signature=').first, messages.last);
    expect(parameters['nonce'], isNot(signed.last.url.queryParameters['nonce']));
  });
  test('acknowledgement alone never confirms the target; current query wins', () async {
    mode = {'multiAssetsMargin': false};
    expect((await change()).observed, FuturesAssetMode.single);
  });
  test(
    'failed POST followed by successful query can verify the target, never replay POST',
    () async {
      postStatus = 503;
      final result = await change();
      expect(result.observed, FuturesAssetMode.multi);
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
    expect((await recheck()).observed, FuturesAssetMode.multi);
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
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'assetModeContextExpired')),
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
  test('missing, malformed or string mode cannot verify a result', () async {
    for (final data in <Object?>[
      null,
      [],
      {},
      {'multiAssetsMargin': 'true'},
    ]) {
      mode = data;
      final result = await recheck();
      expect(result.needsRecheck, true);
      expect(result.failure?.key, 'accountDataInvalid');
    }
  });
  test('invalid target rejected before time, signing or HTTP', () async {
    await expectLater(
      repository.change(
        intent: AssetModeIntent(
          context: assetModeContext(),
          target: FuturesAssetMode.single,
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

  test('all-symbol isolated exposure blocks multi target without any write', () async {
    mode = {'multiAssetsMargin': false};
    positions = assetModeRows(
      symbol: 'ETHUSDT',
      margin: 'isolated',
      quantity: '0.000000000000000000001',
    );
    final context = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(context.isolatedSymbols, ['ETHUSDT']);
    await expectLater(
      repository.change(
        intent: AssetModeIntent(context: context, target: FuturesAssetMode.multi, revision: 0),
        isCurrent: () => true,
        canSubmit: () => true,
        onStep: (_) {},
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('cross positions and empty isolated configurations do not create blockers', () async {
    positions = [
      ...assetModeRows(quantity: '2'),
      ...assetModeRows(symbol: 'ETHUSDT', margin: 'isolated'),
    ];
    final context = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(context.isolatedSymbols, isEmpty);
  });
  test(
    'waiting for the remaining signatures does not reset the first configuration read time',
    () async {
      slowSecondSignature = true;
      final result = await repository.read(
        address: accountAddress,
        isCurrent: () => true,
        onStep: (_) {},
      );
      expect(result.receivedAt, assetModeClock);
      expect(clock.difference(result.receivedAt), const Duration(seconds: 31));
    },
  );

  test(
    'unknown exchange error preserves safe key and code without using its raw message',
    () async {
      mode = {'multiAssetsMargin': false};
      postStatus = 400;
      postBody = jsonEncode({'code': -4999, 'msg': 'raw sensitive response'});
      final result = await change();
      expect(result.observed, FuturesAssetMode.single);
      expect(result.failure?.key, 'accountReadFailed');
      expect(result.failure?.code, -4999);
      expect(requests.where((r) => r.method == 'POST').length, 1);
    },
  );
  test('single-asset target is signed string false with no symbol or margin parameter', () async {
    mode = {'multiAssetsMargin': false};
    final result = await repository.change(
      intent: AssetModeIntent(
        context: assetModeContext(current: FuturesAssetMode.multi),
        target: FuturesAssetMode.single,
        revision: 0,
      ),
      isCurrent: () => true,
      canSubmit: () => true,
      onStep: (_) {},
    );
    expect(result.observed, FuturesAssetMode.single);
    final parameters = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
    expect(parameters['multiAssetsMargin'], 'false');
    expect(parameters.containsKey('symbol'), false);
    expect(parameters.containsKey('marginType'), false);
  });
  test(
    'refusing second preflight signature cannot become an empty isolated position list',
    () async {
      refuse = 2;
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletRejected')),
      );
      expect(requests.where((r) => r.url.path.endsWith('/positionRisk')), isEmpty);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  test('invalid full-account position data fails preflight', () async {
    positions = [
      {...assetModeRows().first, 'marginType': 'unknown'},
    ];
    await expectLater(
      repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'accountDataInvalid')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_rebalance_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import '../../support/aster_account.dart';
import '../../support/rebalance.dart';
import '../../support/wallet_connection.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  late DateTime now;
  late AsterAccountService service;
  late SignedRebalanceRepository repository;
  late List<http.Request> requests;
  late List<Map<String, Object?>> signatures;
  late Map<String, Object?> payload;
  late Object? mode;
  late int status, refuse;
  late String body;
  late bool current, dispatch, prepared;
  late Future<void> Function(int) beforeSend;
  Completer<http.Response>? postGate;
  late void Function() signHook;
  Matcher fails(String key) => throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));
  Future<RebalanceContext> read() =>
      repository.read(address: accountAddress, isCurrent: () => current);
  Future<RebalanceReply> submit(RebalanceContext c) => repository.submit(
    context: c,
    canSubmit: () => current,
    beforeSend: beforeSend,
    onDispatch: () {
      expect(prepared, true);
      dispatch = true;
    },
  );
  setUp(() {
    now = time;
    requests = [];
    signatures = [];
    payload = accountPayload();
    payload['assets'] = [
      {'asset': 'USDT', 'walletBalance': '-1.000000000000000001'},
      {'asset': 'BNB', 'walletBalance': '2.500000000000000001'},
    ];
    mode = {'multiAssetsMargin': true};
    status = 200;
    refuse = 0;
    body = '{"accountId":9007199254740993,"asset":"USDT","balance":"0.000000000000000001","updateTime":1793779200000}';
    current = true;
    dispatch = false;
    prepared = false;
    postGate = null;
    signHook = () {};
    beforeSend = (nonce) async {
      expect(nonce, greaterThan(0));
      expect(dispatch, false);
      prepared = true;
    };
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, false);
        expect(request.url.host, 'fapi.asterdex.com');
        if (request.url.path.endsWith('/time')) {
          return http.Response('{"serverTime":1793779200000}', 200);
        }
        if (request.url.path.endsWith('/multiAssetsMargin')) {
          return http.Response(jsonEncode(mode), 200);
        }
        if (request.url.path == AsterAccountService.accountPath) {
          return http.Response(jsonEncode(payload), 200);
        }
        expect(request.url.path, '/fapi/v3/assetExchange');
        expect(dispatch, true);
        return postGate?.future ?? http.Response(body, status);
      }),
    );
    repository = SignedRebalanceRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        signatures.add(typedData);
        signHook();
        if (signatures.length == refuse) throw const AuthFailure('authWalletRejected');
        return TestWalletConnection.signature;
      },
      nonces: AsterReadNonces(),
      now: () => now,
    );
  });
  tearDown(() => service.close());
  test('read signs exact current-wallet mode and full balances without POST', () async {
    final c = await read();
    expect(c.needed, true);
    expect(c.usdt.toString(), '-1.000000000000000001');
    expect(signatures.length, 2);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    for (final data in signatures) {
      expect((data['domain'] as Map)['chainId'], 1666);
    }
  });
  test('fresh read, immutable intent, pre-send record and exact zero-business-param POST then exact reply', () async {
    final c = await read();
    final reply = await submit(c);
    expect(signatures.length, 5);
    expect(reply.accountId, '9007199254740993');
    expect(reply.balance.toString(), '0.000000000000000001');
    final post = requests.singleWhere((r) => r.method == 'POST');
    final params = Uri.splitQueryString(post.body);
    expect(params.keys.toSet(), {'nonce', 'user', 'signer', 'signature'});
    expect(params['user'], accountAddress);
    expect(params['signer'], accountAddress);
    expect(post.url.query, isEmpty);
    expect(post.body.split('&signature=').first, (signatures.last['message'] as Map)['msg']);
    expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
    expect(requests.where((r) => r.url.path == AsterAccountService.accountPath).length, 2);
  });
  for (final empty in ['', '  \n']) {
    test('documented empty/no-op $empty never invents conversion', () async {
      body = empty;
      expect((await submit(await read())).noExchange, true);
    });
  }
  for (final change in ['mode', 'usdt', 'otherAsset', 'positions', 'wallet']) {
    test('fresh $change drift rejects without dispatch or prewrite', () async {
      final c = await read();
      if (change == 'mode') mode = {'multiAssetsMargin': false};
      if (change == 'usdt') (payload['assets'] as List).first['walletBalance'] = '-2';
      if (change == 'otherAsset') (payload['assets'] as List).last['walletBalance'] = '2';
      if (change == 'positions') (payload['positions'] as List).first['positionAmt'] = '-1';
      final context = change == 'wallet'
          ? rebalanceContext(now: now, address: '0x3333333333333333333333333333333333333333')
          : c;
      await expectLater(submit(context), throwsA(anything));
      expect(dispatch, false);
      expect(prepared, false);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  test('expiry after storage write prevents POST', () async {
    final c = await read();
    beforeSend = (nonce) async {
      prepared = true;
      now = now.add(const Duration(seconds: 30));
    };
    await expectLater(submit(c), fails('rebalanceChanged'));
    expect(dispatch, false);
  });
  test('scope loss during signature cannot persist or POST', () async {
    final c = await read();
    signHook = () {
      current = false;
    };
    await expectLater(submit(c), fails('authWalletChanged'));
    expect(prepared, false);
    expect(dispatch, false);
  });
  test('scope loss after persistence still prevents POST', () async {
    final c = await read();
    beforeSend = (nonce) async {
      prepared = true;
      current = false;
    };
    await expectLater(submit(c), fails('rebalanceChanged'));
    expect(dispatch, false);
  });
  test('known server response after logout is retained for original caller', () async {
    final c = await read();
    postGate = Completer();
    final pending = submit(c);
    while (!dispatch) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    postGate!.complete(http.Response(body, 200));
    expect((await pending).accountId, '9007199254740993');
  });
  for (final invalid in [
    'null',
    '{}',
    '{"code":200,"msg":"success"}',
    '{"accountId":1,"asset":"USDT","balance":0.1,"updateTime":1793779200000}',
    '{"accountId":-1,"asset":"USDT","balance":"0","updateTime":1793779200000}',
    '{"accountId":1,"asset":"USDT","balance":"0","updateTime":0}',
  ]) {
    test('malformed response cannot report a known execution $invalid', () async {
      body = invalid;
      await expectLater(submit(await read()), fails('accountDataInvalid'));
      expect(dispatch, true);
      expect(requests.where((r) => r.method == 'POST').length, 1);
    });
  }
  for (final code in [302, 429, 503]) {
    test('HTTP $code stays failure and is never automatically retried', () async {
      status = code;
      body = '{"msg":"raw private detail"}';
      await expectLater(submit(await read()), throwsA(isA<AccountReadFailure>()));
      expect(requests.where((r) => r.method == 'POST').length, 1);
    });
  }
  test('assetExchange empty decoding does not weaken other endpoints', () async {
    final other = AsterAccountService(client: MockClient((_) async => http.Response('', 200)));
    addTearDown(other.close);
    await expectLater(
      other.changeAssetMode(query: 'nonce=1', signature: TestWalletConnection.signature),
      fails('accountDataInvalid'),
    );
  });
  test('signature rejection before POST leaves no prepared operation', () async {
    final c = await read();
    refuse = 5;
    await expectLater(submit(c), throwsA(isA<AuthFailure>()));
    expect(prepared, false);
    expect(dispatch, false);
  });
  test('domain only offers negative actual USDT wallet balance in multi mode', () {
    expect(rebalanceContext(now: now, usdt: '-0.000000000000000001').needed, true);
    expect(rebalanceContext(now: now, usdt: '0').needed, false);
    expect(rebalanceContext(now: now, missingUsdt: true).needed, false);
    expect(rebalanceContext(now: now, mode: FuturesAssetMode.single).needed, false);
  });
}

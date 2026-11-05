import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/data/signed_internal_transfer_repository.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/internal_transfer.dart';
import '../../support/wallet_connection.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  late DateTime now;
  late SignedInternalTransferRepository repository;
  late AsterAccountService futures;
  late AsterSpotService spot;
  late InternalTransferCatalogService catalog;
  late List<http.Request> requests;
  late List<Map<String, Object?>> signatures;
  late Map<String, Object?> spotPayload, futuresPayload;
  late Object mode, assets, precision;
  late bool current, dispatched, prepared, networkFailure;
  late int status, refuse;
  late String body, signature;
  late void Function() signHook;
  late Future<void> Function(int) beforeSend;
  Completer<http.Response>? postGate;
  late InternalTransferDirection direction;
  Matcher fails(String key) => throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));
  Future<InternalTransferContext> read() => repository.read(
    address: accountAddress,
    asset: 'USDT',
    direction: direction,
    isCurrent: () => current,
  );
  Future<InternalTransferReply> submit(InternalTransferContext c) => repository.submit(
    review: InternalTransferReview(context: c, amount: '1.01', clientId: 'vanta-transfer-original'),
    canSubmit: () => current,
    beforeSend: beforeSend,
    onDispatch: () {
      expect(prepared, true);
      dispatched = true;
    },
  );
  setUp(() {
    now = time;
    current = true;
    dispatched = false;
    prepared = false;
    networkFailure = false;
    requests = [];
    signatures = [];
    spotPayload = transferSpotPayload();
    futuresPayload = transferFuturesPayload();
    mode = {'multiAssetsMargin': true};
    assets = publicRows(['USDT', 'BTC']);
    precision = publicRows([
      {'assetCode': 'USDT', 'assetDecimal': 2},
      {'assetCode': 'BTC', 'assetDecimal': 7},
    ]);
    status = 200;
    refuse = 0;
    postGate = null;
    direction = InternalTransferDirection.spotToFutures;
    body = '{"tranId":9007199254740993,"status":"SUCCESS"}';
    signature = TestWalletConnection.signature;
    signHook = () {};
    beforeSend = (nonce) async {
      expect(nonce, greaterThan(0));
      expect(dispatched, false);
      prepared = true;
    };
    Future<http.Response> handle(http.Request r) async {
      requests.add(r);
      expect(r.followRedirects, false);
      if (r.url.path.endsWith('/time')) return http.Response('{"serverTime":1793779200000}', 200);
      if (r.url.path.endsWith('/transferable')) {
        expect(r.url.host, 'www.asterdex.com');
        return http.Response(jsonEncode(assets), 200);
      }
      if (r.url.path.endsWith('/p-m-asset')) return http.Response(jsonEncode(precision), 200);
      if (r.url.path.endsWith('/multiAssetsMargin')) return http.Response(jsonEncode(mode), 200);
      if (r.url.path == AsterSpotService.accountPath) {
        expect(r.url.host, 'sapi.asterdex.com');
        return http.Response(jsonEncode(spotPayload), 200);
      }
      if (r.url.path == AsterAccountService.accountPath) {
        expect(r.url.host, 'fapi.asterdex.com');
        return http.Response(jsonEncode(futuresPayload), 200);
      }
      expect(r.url.host, 'fapi.asterdex.com');
      expect(r.url.path, '/fapi/v3/asset/wallet/transfer');
      expect(r.method, 'POST');
      expect(dispatched, true);
      if (networkFailure) throw TimeoutException('private detail');
      return postGate?.future ?? http.Response(body, status);
    }

    futures = AsterAccountService(client: MockClient(handle));
    spot = AsterSpotService(client: MockClient(handle));
    catalog = InternalTransferCatalogService(client: MockClient(handle));
    repository = SignedInternalTransferRepository(
      futures,
      spot,
      catalog,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        signatures.add(typedData);
        signHook();
        if (signatures.length == refuse) throw const AuthFailure('authWalletRejected');
        return signature;
      },
      nonces: AsterReadNonces(),
      now: () => now,
    );
  });
  tearDown(() {
    futures.close();
    spot.close();
    catalog.close();
  });
  test('read public support/policy, three exact signatures and no POST', () async {
    final c = await read();
    expect(c.maximum.toString(), '99.000000000000000001');
    expect(signatures.length, 3);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    for (final data in signatures) {
      expect((data['domain'] as Map)['chainId'], 1666);
      final params = Uri.splitQueryString((data['message'] as Map)['msg'] as String);
      expect(params.keys.toSet(), {'nonce', 'user', 'signer'});
      expect(params['user'], accountAddress);
      expect(params['signer'], accountAddress);
    }
  });
  for (final d in InternalTransferDirection.values) {
    test(
      'exact one form POST for $d and ten signatures including final two-account read',
      () async {
        direction = d;
        final c = await read();
        final reply = await submit(c);
        await read();
        expect(signatures.length, 10);
        expect(reply.transactionId, '9007199254740993');
        final post = requests.singleWhere((r) => r.method == 'POST'),
            params = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
        expect(params.keys.toSet(), {
          'amount',
          'asset',
          'clientTranId',
          'kindType',
          'nonce',
          'user',
          'signer',
          'signature',
        });
        expect(params['amount'], '1.01');
        expect(params['asset'], 'USDT');
        expect(params['clientTranId'], 'vanta-transfer-original');
        expect(params['kindType'], d.wire);
        expect(params['user'], accountAddress);
        expect(params['signer'], accountAddress);
        expect(post.url.query, isEmpty);
        expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
        expect(post.body.split('&signature=').first, (signatures[6]['message'] as Map)['msg']);
        final nonces = signatures
            .map(
              (data) => int.parse(
                Uri.splitQueryString((data['message'] as Map)['msg'] as String)['nonce']!,
              ),
            )
            .toList();
        expect(nonces.toSet().length, 10);
        expect([...nonces]..sort(), nonces);
      },
    );
  }
  for (final drift in [
    'free',
    'wallet',
    'cap',
    'sourcePermission',
    'destinationPermission',
    'mode',
    'precision',
    'support',
  ]) {
    test('fresh $drift drift cannot prewrite or dispatch', () async {
      direction = InternalTransferDirection.futuresToSpot;
      final c = await read();
      switch (drift) {
        case 'free':
          (spotPayload['balances'] as List)[1]['free'] = '100';
        case 'wallet':
          (futuresPayload['assets'] as List).first['walletBalance'] = '101';
        case 'cap':
          (futuresPayload['assets'] as List).first['maxWithdrawAmount'] = '20';
        case 'sourcePermission':
          futuresPayload['canWithdraw'] = false;
        case 'destinationPermission':
          spotPayload['canDeposit'] = false;
        case 'mode':
          mode = {'multiAssetsMargin': false};
        case 'precision':
          precision = publicRows([
            {'assetCode': 'USDT', 'assetDecimal': 3},
          ]);
        case 'support':
          assets = publicRows(['BTC']);
      }
      await expectLater(submit(c), fails('internalTransferChanged'));
      expect(prepared, false);
      expect(dispatched, false);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  for (final count in [1, 2, 3, 4, 5, 6, 7]) {
    test('refusal on signature $count prevents POST', () async {
      refuse = count;
      await expectLater(() async {
        final c = await read();
        await submit(c);
      }, count <= 6 ? fails('authWalletRejected') : throwsA(isA<AuthFailure>()));
      expect(dispatched, false);
      expect(prepared, false);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  test('missing cap does not sign mutation or substitute wallet balance', () async {
    direction = InternalTransferDirection.futuresToSpot;
    (futuresPayload['assets'] as List).first.remove('maxWithdrawAmount');
    final c = await read();
    expect(c.maximum, null);
    await expectLater(submit(c), fails('internalTransferChanged'));
    expect(signatures.length, 3);
    expect(dispatched, false);
  });
  test('slow complete read expires original earliest timestamp', () async {
    signHook = () {
      now = now.add(const Duration(seconds: 10));
    };
    await expectLater(read(), fails('internalTransferChanged'));
    expect(signatures.length, 3);
    expect(dispatched, false);
  });
  test('scope loss during read/sign cannot prewrite', () async {
    final c = await read();
    signHook = () {
      current = false;
    };
    await expectLater(submit(c), fails('authWalletChanged'));
    expect(prepared, false);
    expect(dispatched, false);
  });
  for (final cause in ['scope', 'expiry', 'disk']) {
    test('$cause after final signature cannot dispatch', () async {
      final c = await read();
      beforeSend = (nonce) async {
        prepared = true;
        if (cause == 'scope') current = false;
        if (cause == 'expiry') now = now.add(const Duration(seconds: 30));
        if (cause == 'disk') throw const AccountReadFailure('internalTransferStorage');
      };
      await expectLater(submit(c), throwsA(isA<AccountReadFailure>()));
      expect(dispatched, false);
    });
  }
  test('malformed wallet signature never prewrites', () async {
    final c = await read();
    signature = '0x00';
    await expectLater(submit(c), fails('authWalletSignature'));
    expect(prepared, false);
    expect(dispatched, false);
  });
  test('late server response after scope loss returns to original caller', () async {
    final c = await read();
    postGate = Completer();
    final p = submit(c);
    while (!dispatched) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    postGate!.complete(http.Response(body, 200));
    expect((await p).transactionId, '9007199254740993');
  });
  for (final value in [
    '',
    '{}',
    'null',
    '{"status":"PENDING","tranId":1}',
    '{"status":"SUCCESS","tranId":"1"}',
    '{"status":"SUCCESS","tranId":1.1}',
    '{"status":"SUCCESS","tranId":0}',
  ]) {
    test('ambiguous response $value remains unknown without retry', () async {
      body = value;
      await expectLater(submit(await read()), fails('accountDataInvalid'));
      expect(dispatched, true);
      expect(requests.where((r) => r.method == 'POST').length, 1);
    });
  }
  for (final code in [302, 403, 429, 503]) {
    test('HTTP $code does not retry or use raw error detail', () async {
      status = code;
      body = '{"msg":"raw private detail"}';
      await expectLater(submit(await read()), throwsA(isA<AccountReadFailure>()));
      expect(requests.where((r) => r.method == 'POST').length, 1);
    });
  }
  test('POST timeout does not retry', () async {
    networkFailure = true;
    await expectLater(submit(await read()), fails('accountNetwork'));
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
}

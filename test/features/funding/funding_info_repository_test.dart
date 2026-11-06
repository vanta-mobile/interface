import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/data/funding_catalog_repository.dart';
import 'package:vanta/features/funding/data/signed_withdraw_info_repository.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/funding_info.dart';
import '../../support/wallet_connection.dart';

void main() {
  for (final market in TransferMarket.values) {
    for (final operation in FundingOperation.values) {
      test(
        'anonymous catalog GET is scoped to $market $operation on documented host, no redirects',
        () async {
          var calls = 0;
          final service = FundingCatalogService(
            client: MockClient((request) async {
              calls++;
              expect(request.method, 'GET');
              expect(request.followRedirects, false);
              expect(request.url.host, 'www.asterdex.com');
              expect(
                request.url.path,
                '/bapi/futures/v1/public/future/aster/${operation.name}/assets',
              );
              expect(request.url.queryParameters, {
                'chainIds': '1,56,42161',
                'networks': 'EVM',
                'accountType': market.name,
              });
              expect(request.body, isEmpty);
              expect(
                request.headers.keys.any(
                  (key) =>
                      key.toLowerCase().contains('api') || key.toLowerCase() == 'authorization',
                ),
                false,
              );
              return http.Response.bytes(utf8.encode(jsonEncode(fundingCatalogPayload())), 200);
            }),
          );
          addTearDown(service.close);
          final query = FundingCatalogQuery(market, operation);
          final result = await AsterFundingCatalogRepository(service).read(query);
          expect(calls, 1);
          expect(result.query, query);
          expect(result.assets.length, 3);
          await expectLater(service.serverTime(), throwsA(isA<AccountReadFailure>()));
          expect(calls, 1); // No invented public time endpoint.
        },
      );
    }
  }
  test('catalog rejects business failures, redirects and malformed JSON without prices or empty success', () async {
    for (final (response, failure) in [
      (
        http.Response(
          '{"code":"100001","success":false,"message":"Catalog unavailable","data":[]}',
          200,
        ),
        isA<AccountReadFailure>().having(
          (e) => e.details?.message,
          'reason',
          'Catalog unavailable',
        ),
      ),
      (
        http.Response('{}', 302),
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountReadFailed'),
      ),
      (
        http.Response('invalid', 200),
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid'),
      ),
    ]) {
      final service = FundingCatalogService(client: MockClient((_) async => response));
      addTearDown(service.close);
      await expectLater(
        AsterFundingCatalogRepository(service)
            .read(const FundingCatalogQuery(TransferMarket.perp, FundingOperation.deposit)),
        throwsA(failure),
      );
    }
  });
  group('signed withdrawal info', () {
    late AsterAccountService service;
    late SignedWithdrawInfoRepository repository;
    late AsterReadNonces nonces;
    late List<http.Request> requests;
    late List<Map<String, Object?>> messages;
    late bool current;
    late Object? payload;
    late int status;
    AuthFailure? failure;
    Completer<String>? signatureGate;
    Completer<http.Response>? responseGate;
    const ms = 1793707200000;
    setUp(() {
      requests = [];
      messages = [];
      nonces = AsterReadNonces();
      current = true;
      payload = withdrawInfoPayload();
      status = 200;
      failure = null;
      signatureGate = null;
      responseGate = null;
      service = AsterAccountService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.followRedirects, false);
          expect(request.url.host, 'fapi.asterdex.com');
          if (request.url.path == '/fapi/v3/time') return http.Response('{"serverTime":$ms}', 200);
          expect(request.method, 'POST');
          expect(request.url.path, '/fapi/v3/aster/user-withdraw-info');
          expect(request.body, isEmpty);
          return responseGate?.future ??
              http.Response.bytes(utf8.encode(jsonEncode(payload)), status);
        }),
      );
      repository = SignedWithdrawInfoRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          messages.add(typedData);
          if (failure case final error?) throw error;
          return signatureGate?.future ?? TestWalletConnection.signature;
        },
        nonces: nonces,
        now: () => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );
    });
    tearDown(() => service.close());
    Future<Object?> read() =>
        repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {});
    test('exact nanosecond same-EOA signature-last POST only reads info and leaves microsecond counter independent', () async {
      final priorMicro = nonces.next(ms);
      final priorNano = nonces.nextNanoseconds(ms);
      final result = await repository.read(
        address: accountAddress,
        isCurrent: () => current,
        onStep: (_) {},
      );
      expect(result.address, accountAddress);
      expect(result.assets['USDT']!.chains[56]!.fee.toString(), '0.000000000000000001');
      expect(
        messages.single,
        asterReadTypedData('nonce=${priorNano + 1}&user=$accountAddress&signer=$accountAddress'),
      );
      expect(requests.length, 2);
      expect(
        requests.last.url.query,
        'nonce=${priorNano + 1}&user=$accountAddress&signer=$accountAddress&signature=${TestWalletConnection.signature}',
      );
      expect(nonces.next(ms), priorMicro + 1);
      expect(requests.any((r) => r.url.path.endsWith('/user-withdraw')), false);
    });
    test('rejected signing or scope loss during signing never sends a private POST', () async {
      failure = const AuthFailure('authWalletRejected');
      await expectLater(
        read(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
      );
      failure = null;
      signatureGate = Completer();
      final pending = read();
      await Future<void>.delayed(Duration.zero);
      current = false;
      signatureGate!.complete(TestWalletConnection.signature);
      await expectLater(pending, throwsA(isA<AccountReadFailure>()));
      expect(requests.every((r) => r.url.path.endsWith('/time')), true);
    });
    test('scope loss after POST discards info for the former wallet', () async {
      responseGate = Completer();
      final pending = read();
      await Future<void>.delayed(Duration.zero);
      current = false;
      responseGate!.complete(http.Response(jsonEncode(payload), 200));
      await expectLater(
        pending,
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
      );
    });
    test('malformed amounts and server permission errors surface safe failures', () async {
      payload = withdrawInfoPayload()..['userDailyLimit'] = 10000.0;
      await expectLater(
        read(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
      );
      status = 403;
      payload = {'code': -2015, 'msg': 'raw server detail'};
      await expectLater(
        read(),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.key, 'key', 'accountPermissionRequired')
              .having((e) => e.code, 'code', -2015),
        ),
      );
    });
  });
}

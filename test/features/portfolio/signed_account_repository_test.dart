import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_repository.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/aster_account.dart';
import '../../support/wallet_connection.dart';

void main() {
  test('malformed JSON identifies its endpoint without carrying signed query bytes', () async {
    final service = AsterAccountService(
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    addTearDown(service.close);
    await expectLater(
      service.account(
        query: 'nonce=1&user=private-owner',
        signature: TestWalletConnection.signature,
      ),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.details?.cause, 'cause', ApiErrorCause.invalidResponse)
            .having((e) => e.details?.status, 'status', 200)
            .having((e) => e.details?.endpoint, 'safe endpoint', AsterAccountService.accountPath)
            .having((e) => e.details?.message, 'no raw body', isNull),
      ),
    );
  });

  test('deposit-required account stops before dependent contract metadata is queried', () async {
    final paths = <String>[];
    final service = AsterAccountService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return switch (request.url.path) {
          '/fapi/v3/time' => http.Response('{"serverTime":1793620800123}', 200),
          AsterAccountService.accountPath => http.Response('{"code":-5050}', 400),
          _ => throw StateError('Unexpected request'),
        };
      }),
    );
    addTearDown(service.close);
    final repository = SignedAccountRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    await expectLater(
      repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
      throwsA(isA<AccountReadFailure>().having((e) => e.requiresDeposit, 'requiresDeposit', true)),
    );
    expect(paths, ['/fapi/v3/time', AsterAccountService.accountPath]);
  });

  test('account without positions still loads metadata for later account events', () async {
    final payload = accountPayload()..['positions'] = <Object?>[];
    final service = AsterAccountService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(switch (request.url.path) {
            '/fapi/v3/time' => {'serverTime': 1793620800123},
            '/fapi/v3/exchangeInfo' => contractPayload(),
            _ => payload,
          }),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final result = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(result.positions, isEmpty);
    expect(result.units['BTCUSDT']?.base, 'BTC');
  });

  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);

  test(
    'signs exact transmitted bytes with the selected EOA, only GETs and unique nonces',
    () async {
      final requests = <http.Request>[];
      final signed = <Map<String, Object?>>[];
      final stages = <AccountReadStep>[];
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
              _ => accountPayload(),
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final received = DateTime.utc(2026, 11, 2);
      final repository = SignedAccountRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        expect(expectedAddress, accountAddress);
        signed.add(typedData);
        return TestWalletConnection.signature;
      }, now: () => received);
      Future<AsterAccount> read() =>
          repository.read(address: accountAddress, isCurrent: () => true, onStep: stages.add);
      final account = await read();
      await read();
      final reads = requests.where((r) => r.url.path == AsterAccountService.accountPath).toList();
      expect(reads, hasLength(2));
      for (var i = 0; i < reads.length; i++) {
        final query = reads[i].url.query;
        expect((signed[i]['message']! as Map)['msg'], query.split('&signature=').first);
        expect(reads[i].url.queryParameters['user'], accountAddress);
        expect(reads[i].url.queryParameters['signer'], accountAddress);
        expect(reads[i].url.queryParameters['signature'], TestWalletConnection.signature);
        expect(signed[i]['domain'], {
          'name': 'AsterSignTransaction',
          'version': '1',
          'chainId': 1666,
          'verifyingContract': '0x0000000000000000000000000000000000000000',
        });
      }
      expect(reads.first.url.queryParameters['nonce'], '1793620800123000');
      expect(reads.last.url.queryParameters['nonce'], '1793620800123001');
      expect(account.receivedAt, received);
      expect(account.positions.single.units?.base, 'BTC');
      expect(stages, [
        AccountReadStep.preparing,
        AccountReadStep.signing,
        AccountReadStep.loading,
        AccountReadStep.preparing,
        AccountReadStep.signing,
        AccountReadStep.loading,
      ]);
    },
  );

  test('wallet rejection or account change after the prompt sends no signed request', () async {
    for (final rejected in [true, false]) {
      var requests = 0;
      var current = true;
      final service = AsterAccountService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{"serverTime":1793620800123}', 200);
        }),
      );
      final repository = SignedAccountRepository(service, ({
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
      expect(requests, 1);
      service.close();
    }
  });

  test(
    'late time response, invalid address and invalid signature do not reach account API',
    () async {
      final gate = Completer<http.Response>();
      var requests = 0;
      var signs = 0;
      var current = true;
      final service = AsterAccountService(
        client: MockClient((_) {
          requests++;
          return gate.future;
        }),
      );
      addTearDown(service.close);
      final repository = SignedAccountRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        signs++;
        return 'invalid';
      });
      Future<AsterAccount> read(String address) =>
          repository.read(address: address, isCurrent: () => current, onStep: (_) {});
      await expectLater(read('invalid'), throwsA(failure('authWalletChanged')));
      expect(requests, 0);
      final pending = read(accountAddress);
      current = false;
      gate.complete(http.Response('{"serverTime":1793620800123}', 200));
      await expectLater(pending, throwsA(failure('authWalletChanged')));
      expect(signs, 0);
      current = true;
      await expectLater(read(accountAddress), throwsA(failure('authWalletSignature')));
      expect(requests, 2); // only the two time reads
    },
  );

  test('public metadata failure preserves signed data and makes position units unknown', () async {
    final service = AsterAccountService(
      client: MockClient(
        (request) async => switch (request.url.path) {
          '/fapi/v3/time' => http.Response('{"serverTime":1793620800123}', 200),
          '/fapi/v3/exchangeInfo' => http.Response('offline', 503),
          _ => http.Response(jsonEncode(accountPayload()), 200),
        },
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final account = await repository.read(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(account.walletBalance.toString(), '100.000000000000000001');
    expect(account.positions.single.units, null);
  });

  for (final scenario in [
    (429, '{}', 'accountRateLimited', null),
    (418, '{}', 'accountRateLimited', null),
    (403, '{"msg":"sensitive raw response"}', 'accountPermissionRequired', null),
    (400, '{"code":-2015,"msg":"sensitive raw response"}', 'accountPermissionRequired', -2015),
    (400, '{"code":-5050,"msg":"sensitive raw response"}', 'accountDepositRequired', -5050),
    (400, '{"code":-1021}', 'accountSignatureExpired', -1021),
    (200, '{"code":-1022}', 'accountSignatureRejected', -1022),
    (302, '', 'accountReadFailed', null),
    (503, 'unavailable', 'accountReadFailed', null),
    (200, 'unavailable', 'accountDataInvalid', null),
  ]) {
    test('maps safe account failure ${scenario.$1} ${scenario.$3}', () async {
      var calls = 0;
      final service = AsterAccountService(
        client: MockClient((request) async {
          calls++;
          expect(request.followRedirects, false);
          return http.Response(
            scenario.$2,
            scenario.$1,
            headers: {'location': 'https://other.invalid'},
          );
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.account(query: 'nonce=1', signature: TestWalletConnection.signature),
        throwsA(failure(scenario.$3).having((AccountReadFailure e) => e.code, 'code', scenario.$4)),
      );
      expect(calls, 1); // no automatic retries or redirection
    });
  }

  test('transport exceptions become safe network failures', () async {
    final service = AsterAccountService(
      client: MockClient((_) async => throw http.ClientException('raw sensitive URL')),
    );
    addTearDown(service.close);
    await expectLater(service.serverTime(), throwsA(failure('accountNetwork')));
  });

  test(
    'account responses decode UTF-8 identifiers independently of content-type headers',
    () async {
      final payload = accountPayload()
        ..['positions'] = [
          {'symbol': '币安人生USDT', 'positionSide': 'BOTH', 'positionAmt': '1'},
        ];
      final service = AsterAccountService(
        client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(payload)), 200)),
      );
      addTearDown(service.close);
      final result = await service.account(
        query: 'nonce=1',
        signature: TestWalletConnection.signature,
      );
      expect((result! as Map<String, dynamic>)['positions'], [
        {'symbol': '币安人生USDT', 'positionSide': 'BOTH', 'positionAmt': '1'},
      ]);
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/data/signed_transfer_history_repository.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/transfers.dart';
import '../../support/wallet_connection.dart';

void main() {
  test('funding and trading share unique microsecond nonces for repeated or older time', () {
    final nonces = AsterReadNonces();
    expect(nonces.next(1793620800123), 1793620800123000);
    expect(nonces.next(1793620800122), 1793620800123001);
    expect(nonces.next(1793620800123), 1793620800123002);
    for (final time in [0, -1, 9223372036854776]) {
      expect(() => nonces.next(time), throwsFormatException);
    }
  });
  test(
    'read-only POST signs exact query with V3 microseconds, same EOA and no extra params',
    () async {
      final requests = <http.Request>[], signed = <String>[], steps = <AccountReadStep>[];
      const serverTime = 1793620800123;
      final nonces = AsterReadNonces()..next(serverTime);
      final service = AsterAccountService(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(r.method == 'POST' ? [transferPayload()] : {'serverTime': serverTime}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final repository = SignedTransferHistoryRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          expect((typedData['domain'] as Map)['chainId'], 1666);
          signed.add((typedData['message'] as Map)['msg'] as String);
          return TestWalletConnection.signature;
        },
        nonces: nonces,
        now: () => DateTime.utc(2026, 11, 3),
      );
      for (var i = 0; i < 2; i++) {
        final result = await repository.read(
          address: accountAddress,
          isCurrent: () => true,
          onStep: steps.add,
        );
        expect(result.records.single.id, '1234567');
        expect(result.address, accountAddress);
        final request = requests.last;
        expect(request.method, 'POST');
        expect(request.url.origin, 'https://fapi.asterdex.com');
        expect(request.url.path, '/fapi/v3/aster/deposit-withdraw-history');
        expect(request.body, '');
        expect(request.followRedirects, false);
        expect(request.url.query, '${signed[i]}&signature=${TestWalletConnection.signature}');
        expect(Uri.splitQueryString(signed[i]), {
          'nonce': '${1793620800123001 + i}',
          'user': accountAddress,
          'signer': accountAddress,
        });
      }
      expect(nonces.next(serverTime), 1793620800123003);
      expect(steps, [
        for (var i = 0; i < 2; i++) ...[
          AccountReadStep.preparing,
          AccountReadStep.signing,
          AccountReadStep.loading,
        ],
      ]);
      expect(requests.length, 4);
    },
  );
  for (final reason in ['refusal', 'walletChange', 'lateResponse']) {
    test('$reason cannot produce a valid account result', () async {
      var current = true, posts = 0;
      final service = AsterAccountService(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            if (reason == 'lateResponse') current = false;
          }
          return http.Response(
            jsonEncode(r.method == 'POST' ? [transferPayload()] : {'serverTime': 1793620800123}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final repository = SignedTransferHistoryRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        if (reason == 'refusal') throw const AuthFailure('authWalletRejected');
        if (reason == 'walletChange') current = false;
        return TestWalletConnection.signature;
      }, nonces: AsterReadNonces());
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
        throwsA(
          isA<AccountReadFailure>().having(
            (e) => e.key,
            'key',
            reason == 'refusal' ? 'authWalletRejected' : 'authWalletChanged',
          ),
        ),
      );
      expect(posts, reason == 'lateResponse' ? 1 : 0);
    });
  }
  test('authorization failures, redirects, rate limits and invalid history stay safe', () async {
    for (final item in [
      ({'code': -2015, 'msg': 'private secret'}, 403, 'accountPermissionRequired'),
      (<Object?>[], 302, 'accountReadFailed'),
      (<Object?>[], 429, 'accountRateLimited'),
      ([transferPayload()..['amount'] = 1.2], 200, 'accountDataInvalid'),
    ]) {
      final service = AsterAccountService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(r.method == 'POST' ? item.$1 : {'serverTime': 1793620800123}),
            r.method == 'POST' ? item.$2 : 200,
          ),
        ),
      );
      final repository = SignedTransferHistoryRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
        nonces: AsterReadNonces(),
      );
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', item.$3)),
      );
      service.close();
    }
  });
  test(
    'device-time rejection preserves the server message without replaying the request',
    () async {
      const message = 'Your device time must match the actual time.';
      var posts = 0, rejectedGrants = 0;
      final service = AsterAccountService(
        client: MockClient((request) async {
          if (request.method != 'POST') {
            return http.Response('{"serverTime":1793620800123}', 200);
          }
          posts++;
          return http.Response(jsonEncode({'code': -1000, 'msg': message}), 400);
        }),
      );
      addTearDown(service.close);
      final repository = SignedTransferHistoryRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
        nonces: AsterReadNonces(),
        authorization: (_) async => AccountRequestIdentity(
          address: accountAddress,
          sign: ({required expectedAddress, required typedData}) async =>
              TestWalletConnection.signature,
          onRejected: () async {
            rejectedGrants++;
          },
        ),
      );
      await expectLater(
        repository.read(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.code, 'code', -1000)
              .having((e) => e.details?.message, 'message', message),
        ),
      );
      expect(posts, 1);
      expect(rejectedGrants, 0);
    },
  );
  test('a blocked time read never asks a wallet after the account changes', () async {
    var signs = 0, current = true;
    final gate = Completer<http.Response>();
    final service = AsterAccountService(client: MockClient((_) => gate.future));
    addTearDown(service.close);
    final repository = SignedTransferHistoryRepository(service, ({
      required expectedAddress,
      required typedData,
    }) async {
      signs++;
      return TestWalletConnection.signature;
    }, nonces: AsterReadNonces());
    final pending = repository.read(
      address: accountAddress,
      isCurrent: () => current,
      onStep: (_) {},
    );
    current = false;
    gate.complete(http.Response('{"serverTime":1793620800123}', 200));
    await expectLater(pending, throwsA(isA<AccountReadFailure>()));
    expect(signs, 0);
  });
}

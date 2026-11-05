import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_account_change_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/wallet_connection.dart';

void main() {
  const key = 'exampleLocalTestKey000000000000001';
  TypeMatcher<AccountReadFailure> failure(String key) =>
      isA<AccountReadFailure>().having((e) => e.key, 'key', key);
  test(
    'POST start/renew signs exact form bytes with direct EOA and unique shared nonce; no DELETE',
    () async {
      final requests = <http.Request>[];
      final signed = <String>[];
      var clock = DateTime.utc(2026, 11, 3);
      final service = AsterAccountService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.followRedirects, false);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/time')
                  ? {'serverTime': 1793620800123}
                  : {'listenKey': key},
            ),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final nonces = AsterReadNonces()..next(1793620800123);
      final repository = SignedAccountChangeRepository(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          expect((typedData['domain']! as Map)['chainId'], 1666);
          signed.add((typedData['message']! as Map)['msg'] as String);
          clock = clock.add(const Duration(seconds: 2));
          return TestWalletConnection.signature;
        },
        nonces: nonces,
        now: () => clock,
      );
      for (var i = 0; i < 2; i++) {
        final started = clock;
        expect(
          await repository.authorize(
            address: accountAddress,
            isCurrent: () => true,
            onStep: (_) {},
          ),
          started.add(const Duration(minutes: 60)),
        );
      }
      final posts = requests.where((r) => r.method == 'POST').toList();
      expect(posts.length, 2);
      for (var i = 0; i < 2; i++) {
        final post = posts[i];
        expect(post.url.toString(), 'https://fapi.asterdex.com/fapi/v3/listenKey');
        expect(post.headers['content-type'], contains('application/x-www-form-urlencoded'));
        expect(post.body, '${signed[i]}&signature=${TestWalletConnection.signature}');
        expect(Uri.splitQueryString(signed[i]), {
          'nonce': '${1793620800123001 + i}',
          'user': accountAddress,
          'signer': accountAddress,
        });
      }
      repository.clear();
      expect((await repository.connect().single).expired, true);
      expect(requests.length, 4);
    },
  );
  test('refusal or identity change before POST never sends private request', () async {
    for (final reject in [true, false]) {
      var current = true;
      var posts = 0;
      final service = AsterAccountService(
        client: MockClient((r) async {
          if (r.method == 'POST') posts++;
          return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
        }),
      );
      final repository = SignedAccountChangeRepository(service, ({
        required expectedAddress,
        required typedData,
      }) async {
        if (reject) throw const AuthFailure('authWalletRejected');
        current = false;
        return TestWalletConnection.signature;
      });
      await expectLater(
        repository.authorize(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
        throwsA(failure(reject ? 'authWalletRejected' : 'authWalletChanged')),
      );
      expect(posts, 0);
      service.close();
    }
  });
  test('clear while POST pending discards the returned secret and cannot connect', () async {
    final gate = Completer<http.Response>();
    final service = AsterAccountService(
      client: MockClient(
        (r) async => r.method == 'POST'
            ? gate.future
            : http.Response(jsonEncode({'serverTime': 1793620800123}), 200),
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountChangeRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
    );
    final pending = repository.authorize(
      address: accountAddress,
      isCurrent: () => true,
      onStep: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    repository.clear();
    gate.complete(http.Response(jsonEncode({'listenKey': key}), 200));
    await expectLater(pending, throwsA(failure('authWalletChanged')));
    expect((await repository.connect().single).expired, true);
  });
  test('expired local lease cannot open a socket', () async {
    var clock = DateTime.utc(2026, 11, 3);
    final service = AsterAccountService(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(r.method == 'POST' ? {'listenKey': key} : {'serverTime': 1793620800123}),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountChangeRepository(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      now: () => clock,
      connect: (_) => throw StateError('Must not connect'),
    );
    await repository.authorize(address: accountAddress, isCurrent: () => true, onStep: (_) {});
    clock = clock.add(const Duration(minutes: 60));
    expect((await repository.connect().single).expired, true);
  });
  test('malformed keys, protocol rejection and redirect never expose raw server text', () async {
    for (final item in [
      ({'listenKey': 'https://bad.invalid/secret'}, 200),
      ({'listenKey': ''}, 200),
      ({'code': -2015, 'msg': key}, 400),
      ({'listenKey': key}, 302),
    ]) {
      final service = AsterAccountService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(r.method == 'POST' ? item.$1 : {'serverTime': 1793620800123}),
            r.method == 'POST' ? item.$2 : 200,
          ),
        ),
      );
      final repository = SignedAccountChangeRepository(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      await expectLater(
        repository.authorize(address: accountAddress, isCurrent: () => true, onStep: (_) {}),
        throwsA(isA<AccountReadFailure>()),
      );
      expect((await repository.connect().single).expired, true);
      service.close();
    }
  });
}

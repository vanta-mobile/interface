import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/notifications/data/notification_units_repository.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_account_change_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/wallet_connection.dart';

void main() {
  const key = 'spotLocalTestKey00000000000001';
  test(
    'Spot start and renewal sign exact POST bytes with shared nonce, same EOA and no DELETE/PUT',
    () async {
      final requests = <http.Request>[], signed = <String>[];
      var now = DateTime.utc(2026, 11, 3);
      final service = AsterSpotService(
        client: MockClient((r) async {
          requests.add(r);
          expect(r.followRedirects, false);
          return http.Response(
            jsonEncode(r.method == 'POST' ? {'listenKey': key} : {'serverTime': 1793620800123}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final nonces = AsterReadNonces()..next(1793620800123);
      final repository = SignedAccountChangeRepository.spot(
        service,
        ({required expectedAddress, required typedData}) async {
          expect(expectedAddress, accountAddress);
          expect((typedData['domain'] as Map)['chainId'], 1666);
          signed.add((typedData['message'] as Map)['msg'] as String);
          now = now.add(const Duration(seconds: 2));
          return TestWalletConnection.signature;
        },
        nonces: nonces,
        now: () => now,
      );
      for (var i = 0; i < 2; i++) {
        final started = now;
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
        expect(posts[i].url.toString(), 'https://sapi.asterdex.com/api/v3/listenKey');
        expect(posts[i].body, '${signed[i]}&signature=${TestWalletConnection.signature}');
        expect(posts[i].headers['content-type'], contains('application/x-www-form-urlencoded'));
        expect(Uri.splitQueryString(signed[i]), {
          'nonce': '${1793620800123001 + i}',
          'user': accountAddress,
          'signer': accountAddress,
        });
      }
      repository.clear();
      expect((await repository.connect().single).expired, true);
      expect(requests.length, 4);
      expect(requests.any((r) => r.method == 'DELETE' || r.method == 'PUT'), false);
    },
  );
  for (final reject in [true, false]) {
    test(
      'Spot ${reject ? 'refusal' : 'identity change'} before send prevents private POST',
      () async {
        var current = true, posts = 0;
        final service = AsterSpotService(
          client: MockClient((r) async {
            if (r.method == 'POST') posts++;
            return http.Response(jsonEncode({'serverTime': 1793620800123}), 200);
          }),
        );
        addTearDown(service.close);
        final repository = SignedAccountChangeRepository.spot(service, ({
          required expectedAddress,
          required typedData,
        }) async {
          if (reject) throw const AuthFailure('authWalletRejected');
          current = false;
          return TestWalletConnection.signature;
        });
        await expectLater(
          repository.authorize(address: accountAddress, isCurrent: () => current, onStep: (_) {}),
          throwsA(
            isA<AccountReadFailure>().having(
              (f) => f.key,
              'key',
              reject ? 'authWalletRejected' : 'authWalletChanged',
            ),
          ),
        );
        expect(posts, 0);
      },
    );
  }
  test('pending Spot key is discarded after clear', () async {
    final gate = Completer<http.Response>();
    final service = AsterSpotService(
      client: MockClient(
        (r) async => r.method == 'POST'
            ? gate.future
            : http.Response(jsonEncode({'serverTime': 1793620800123}), 200),
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountChangeRepository.spot(
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
    await expectLater(pending, throwsA(isA<AccountReadFailure>()));
    expect((await repository.connect().single).expired, true);
  });
  test('Spot invalid keys and HTTP failures remain safe and cannot connect', () async {
    for (final item in [
      ({'listenKey': ''}, 200),
      ({'listenKey': 'https://secret.invalid/key'}, 200),
      ({'code': -2015, 'msg': key}, 400),
      ({'listenKey': key}, 302),
    ]) {
      final service = AsterSpotService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(r.method == 'POST' ? item.$1 : {'serverTime': 1793620800123}),
            r.method == 'POST' ? item.$2 : 200,
          ),
        ),
      );
      final repository = SignedAccountChangeRepository.spot(
        service,
        ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      );
      try {
        await repository.authorize(address: accountAddress, isCurrent: () => true, onStep: (_) {});
        fail('Expected safe failure');
      } on AccountReadFailure catch (e) {
        expect(e.toString(), isNot(contains(key)));
      }
      expect((await repository.connect().single).expired, true);
      service.close();
    }
  });
  test('Spot repository opens only the spot host and enforces the local lease deadline', () async {
    var clock = DateTime.utc(2026, 11, 3);
    Uri? requested;
    final service = AsterSpotService(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(r.method == 'POST' ? {'listenKey': key} : {'serverTime': 1793620800123}),
          200,
        ),
      ),
    );
    addTearDown(service.close);
    final repository = SignedAccountChangeRepository.spot(
      service,
      ({required expectedAddress, required typedData}) async => TestWalletConnection.signature,
      now: () => clock,
      connect: (uri) {
        requested = uri;
        throw StateError('private URI must not escape');
      },
    );
    await repository.authorize(address: accountAddress, isCurrent: () => true, onStep: (_) {});
    await expectLater(
      repository.connect().toList(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'accountNetwork')),
    );
    expect(requested.toString(), 'wss://sstream.asterdex.com/ws/$key');
    requested = null;
    clock = clock.add(const Duration(minutes: 60));
    expect((await repository.connect().single).expired, true);
    expect(requested, null);
  });
  test(
    'Spot public unit directory uses sapi exchangeInfo and keeps exact base/quote metadata',
    () async {
      final service = AsterSpotService(
        client: MockClient((r) async {
          expect(r.url.toString(), 'https://sapi.asterdex.com/api/v3/exchangeInfo');
          expect(r.method, 'GET');
          return http.Response(
            jsonEncode({
              'symbols': [
                {'symbol': 'BTCUSDT', 'baseAsset': 'BTC', 'quoteAsset': 'USDT'},
                {'symbol': 'SAMESUFFIX', 'baseAsset': 'REAL_BASE', 'quoteAsset': 'REAL_QUOTE'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final units = await AsterSpotNotificationUnitsRepository(service).read();
      expect(units['BTCUSDT']!.base, 'BTC');
      expect(units['SAMESUFFIX']!.base, 'REAL_BASE');
      expect(units['SAMESUFFIX']!.quote, 'REAL_QUOTE');
    },
  );
}

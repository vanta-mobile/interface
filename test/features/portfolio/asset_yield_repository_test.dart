import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/asset_yield_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_yield.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4);
  const usdf =
      '{"code":"000000","success":true,"data":{'
      '"baseApyList":[{"day":"2026-11-04","apy":1.75}],'
      '"tradeApyList":[{"day":"2026-11-04","apy":9.70}]}}';
  const lista =
      '{"code":"000000000","data":{"comprehensiveApy":"0.014499999999999999",'
      '"time":"2026-11-04","updateTime":1793750400000}}';
  PublicAssetYieldRepository repository(
    Future<http.Response> Function(http.Request) handle, {
    Duration timeout = const Duration(seconds: 12),
  }) {
    final aster = AsterYieldService(client: MockClient(handle), timeout: timeout);
    final lista = ListaYieldService(client: MockClient(handle), timeout: timeout);
    addTearDown(aster.close);
    addTearDown(lista.close);
    return PublicAssetYieldRepository(aster, lista, now: () => now);
  }

  test(
    'fixed anonymous origins/paths, no authentication or wallet fields; one request per asset',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.body, '');
        expect(request.followRedirects, false);
        expect(request.headers, {'Accept': 'application/json'});
        return http.Response(request.url.host == 'www.asterdex.com' ? usdf : lista, 200);
      });
      expect((await repo.read(YieldAsset.usdf)).percent.toString(), '11.45');
      expect((await repo.read(YieldAsset.asbnb)).percent.toString(), '1.4499999999999999');
      expect(requests.map((r) => r.url.toString()), [
        'https://www.asterdex.com/bapi/futures/v1/public/future/aster/usdf/info?day=7',
        'https://api.lista.org/v1/stakes/latest-apr',
      ]);
    },
  );
  for (final status in [302, 401, 403, 429, 500, 503]) {
    test('HTTP $status fails safely without following or retrying', () async {
      var calls = 0;
      final repo = repository((_) async {
        calls++;
        return http.Response(
          'sensitive raw error',
          status,
          headers: {'location': 'https://untrusted.invalid'},
        );
      });
      await expectLater(repo.read(YieldAsset.usdf), throwsA(isA<AccountReadFailure>()));
      expect(calls, 1);
    });
  }
  for (final source in [
    '{}',
    '{"code":"000000000","data":{}}',
    '{"code":"bad","data":{}}',
    lista.replaceFirst('0.014499999999999999', 'NaN'),
  ]) {
    test('invalid Lista response produces safe data failure (${source.hashCode})', () async {
      final repo = repository((_) async => http.Response(source, 200));
      await expectLater(
        repo.read(YieldAsset.asbnb),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
      );
    });
  }
  test('timeout returns a network reason without retry', () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final repo = repository((_) {
      calls++;
      return gate.future;
    }, timeout: const Duration(milliseconds: 1));
    await expectLater(
      repo.read(YieldAsset.usdf),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountNetwork')),
    );
    gate.complete(http.Response(usdf, 200));
    expect(calls, 1);
  });
}

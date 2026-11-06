import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/network/backend_http_pool.dart';
import 'package:vanta/core/network/managed_http_client.dart';
import 'package:vanta/core/network/request_scope.dart';

void main() {
  test('leases reuse same-origin transport and isolate different origins', () async {
    var created = 0;
    final pool = BackendHttpPool(
      createClient: () {
        created++;
        return MockClient((_) async => http.Response('ok', 200));
      },
    );
    final a = ManagedHttpClient(pool.lease()), b = ManagedHttpClient(pool.lease());
    addTearDown(() {
      a.close();
      b.close();
      pool.close();
    });
    await a.get(Uri.https('fapi.asterdex.com', '/first'));
    a.close();
    expect((await b.get(Uri.https('fapi.asterdex.com', '/second'))).body, 'ok');
    expect(created, 1);
    await b.get(Uri.https('sapi.asterdex.com', '/second'));
    expect(created, 2);
  });

  test('host Retry-After applies across leases; cancelling queue never sends request', () async {
    var calls = 0;
    final pool = BackendHttpPool(
      createClient: () => MockClient((_) async {
        calls++;
        return http.Response('', 429, headers: {'retry-after': '60'});
      }),
    );
    final a = ManagedHttpClient(pool.lease()), b = ManagedHttpClient(pool.lease());
    addTearDown(() {
      a.close();
      b.close();
      pool.close();
    });
    await a.get(Uri.https('fapi.asterdex.com', '/first'));
    var current = true;
    final pending = RequestScope.run(
      () => current,
      () => b.get(Uri.https('fapi.asterdex.com', '/queued')),
    );
    final failure = expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 1);
    current = false;
    await failure;
    expect(calls, 1);
    // Another host has an independent cooldown and proceeds immediately.
    await b.get(Uri.https('sapi.asterdex.com', '/independent'));
    expect(calls, 2);
  });

  test('pool disposal releases queued requests without waiting for Retry-After', () async {
    final pool = BackendHttpPool(
      createClient: () =>
          MockClient((_) async => http.Response('', 429, headers: {'retry-after': '60'})),
    );
    final client = ManagedHttpClient(pool.lease());
    addTearDown(client.close);
    await client.get(Uri.https('fapi.asterdex.com'));
    final pending = client.get(Uri.https('fapi.asterdex.com'));
    final failure = expectLater(pending, throwsA(isA<http.ClientException>()));
    await Future<void>.delayed(Duration.zero);
    pool.close();
    await failure;
  });

  test('weighted public budget is shared across repository leases', () async {
    var sent = 0;
    final pool = BackendHttpPool(
      createClient: () => MockClient((_) async {
        sent++;
        return http.Response('[]', 200);
      }),
    );
    final a = ManagedHttpClient(pool.lease()), b = ManagedHttpClient(pool.lease());
    addTearDown(() {
      a.close();
      b.close();
      pool.close();
    });
    for (var i = 0; i < 25; i++) {
      await (i.isEven ? a : b).get(Uri.https('fapi.asterdex.com', '/fapi/v3/ticker/24hr'));
    }
    final blocked = b.get(Uri.https('fapi.asterdex.com', '/fapi/v3/time'));
    final failure = expectLater(blocked, throwsA(isA<http.RequestAbortedException>()));
    await Future<void>.delayed(Duration.zero);
    expect(sent, 25);
    b.close();
    await failure;
    expect(sent, 25);
  });
}

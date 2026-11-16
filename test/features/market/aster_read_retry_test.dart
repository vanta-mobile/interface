import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/public_leverage_repository.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/wallet_connection.dart';

void main() {
  for (final headersReceived in [false, true]) {
    test(
      'account timeout aborts each ${headersReceived ? 'body' : 'header'} wait before retry',
      () {
        fakeAsync((time) {
          var calls = 0, aborts = 0, cancellations = 0;
          Object? error;
          final bodies = <StreamController<List<int>>>[];
          final service = AsterAccountService(
            timeout: const Duration(milliseconds: 100),
            client: MockClient.streaming((request, bytes) async {
              await bytes.drain<void>();
              calls++;
              (request as http.Abortable).abortTrigger!.then((_) => aborts++);
              if (!headersReceived) return Completer<http.StreamedResponse>().future;
              final body = StreamController<List<int>>(onCancel: () => cancellations++);
              bodies.add(body);
              return http.StreamedResponse(body.stream, 200);
            }),
          );
          service.serverTime().then<void>(
            (_) => fail('Expected timeout'),
            onError: (Object e) => error = e,
          );
          time.elapse(const Duration(milliseconds: 1300));
          expect(calls, 3);
          expect(aborts, 3);
          expect(cancellations, headersReceived ? 3 : 0);
          expect(
            error,
            isA<AccountReadFailure>().having(
              (e) => e.details?.cause,
              'cause',
              ApiErrorCause.timeout,
            ),
          );
          service.close();
          for (final body in bodies) {
            body.close();
          }
          time.flushMicrotasks();
          expect(time.nonPeriodicTimerCount, 0);
          expect(time.periodicTimerCount, 0);
        });
      },
    );
  }

  test('closing one account service during backoff preserves other consumers', () {
    fakeAsync((time) {
      var aCalls = 0;
      Object? aError, bResult;
      final a = AsterAccountService(
        client: MockClient((_) async {
          aCalls++;
          return http.Response('{}', 503);
        }),
      );
      final b = AsterAccountService(
        client: MockClient((_) async => http.Response('{"serverTime":123}', 200)),
      );
      a.serverTime().then<void>(
        (_) => fail('Expected cancellation'),
        onError: (Object e) => aError = e,
      );
      time.flushMicrotasks();
      a.close();
      b.serverTime().then((value) => bResult = value);
      time.elapse(const Duration(seconds: 1));
      expect(aCalls, 1);
      expect(
        aError,
        isA<AccountReadFailure>().having((e) => e.details?.cause, 'cause', ApiErrorCause.cancelled),
      );
      expect(bResult, 123);
      b.close();
    });
  });

  test('public market read hides two failures before returning recovered data', () {
    fakeAsync((time) {
      var calls = 0;
      final service = AsterService(
        MockClient(
          (_) async => ++calls < 3
              ? http.Response('{"msg":"Temporary outage"}', 503)
              : http.Response('{"serverTime":123}', 200),
        ),
      );
      Object? result;
      service.request('/fapi/v3/time').then((data) => result = data);
      time.flushMicrotasks();
      expect(result, isNull);
      time.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(result, {'serverTime': 123});
      service.dispose();
    });
  });

  test('exhausted market reads preserve the last API error message', () {
    fakeAsync((time) {
      var calls = 0;
      Object? error;
      final service = AsterService(
        MockClient((_) async => http.Response('{"msg":"Unavailable ${++calls}"}', 503)),
      );
      service
          .request('/fapi/v3/time')
          .then<void>((_) => fail('Expected failure'), onError: (Object e) => error = e);
      time.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(
        error,
        isA<MarketFailure>().having((e) => e.details?.message, 'message', 'Unavailable 3'),
      );
      service.dispose();
    });
  });

  for (final body in ['{"code":-1022,"msg":"Signature rejected"}', '<html>']) {
    test('business rejection or malformed success is not retried: $body', () async {
      var calls = 0;
      final service = AsterService(
        MockClient((_) async {
          calls++;
          return http.Response(body, 200);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(service.request('/fapi/v3/time'), throwsA(isA<MarketFailure>()));
      expect(calls, 1);
    });
  }

  test('signed account GET retries identical bytes without a new wallet prompt', () {
    fakeAsync((time) {
      final queries = <String>[];
      final service = AsterAccountService(
        client: MockClient((request) async {
          queries.add(request.url.query);
          expect(request.followRedirects, false);
          return http.Response(
            queries.length < 3 ? '{}' : '{"ok":true}',
            queries.length < 3 ? 502 : 200,
          );
        }),
      );
      Object? result;
      service
          .account(query: 'nonce=1', signature: TestWalletConnection.signature)
          .then((data) => result = data);
      time.elapse(const Duration(seconds: 1));
      expect(queries, hasLength(3));
      expect(queries.toSet(), hasLength(1));
      expect(result, {'ok': true});
      service.close();
    });
  });

  for (final method in ['POST', 'PUT', 'DELETE']) {
    test('financial $method is sent only once on a transient failure', () async {
      var calls = 0;
      final service = AsterAccountService(
        client: MockClient((request) async {
          expect(request.method, method);
          calls++;
          return http.Response('{"msg":"Temporary outage"}', 503);
        }),
      );
      addTearDown(service.close);
      final operation = switch (method) {
        'POST' => service.newOrder,
        'PUT' => service.modifyOrder,
        _ => service.cancelOrder,
      };
      await expectLater(
        operation(query: 'nonce=1', signature: TestWalletConnection.signature),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(calls, 1);
    });
  }

  test('public read-only brackets POST recovers after two failures', () {
    fakeAsync((time) {
      var calls = 0, completed = false;
      final repository = PublicLeverageRepository(
        MockClient((request) async {
          expect(request.method, 'POST');
          return ++calls < 3
              ? http.Response('{}', 503)
              : http.Response('{"success":true,"code":"000000","data":{"brackets":[]}}', 200);
        }),
      );
      repository.read().then((_) => completed = true);
      time.elapse(const Duration(seconds: 1));
      expect(calls, 3);
      expect(completed, isTrue);
      repository.dispose();
    });
  });
}

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/core/network/safe_read_retry.dart';

void main() {
  for (final status in [408, 418, 429, 500, 502, 503, 504]) {
    test('transient HTTP $status recovers on the third attempt', () {
      fakeAsync((time) {
        final retry = SafeReadRetry();
        var calls = 0;
        http.Response? result;
        retry
            .run(() async => http.Response('', ++calls < 3 ? status : 200))
            .then((r) => result = r);
        time.flushMicrotasks();
        expect(calls, 1);
        expect(result, isNull);
        time.elapse(const Duration(milliseconds: 300));
        expect(calls, 2);
        expect(result, isNull);
        time.elapse(const Duration(milliseconds: 600));
        expect(calls, 3);
        expect(result?.statusCode, 200);
        retry.close();
      });
    });
  }

  test('exhaustion returns the final response and its concrete error', () {
    fakeAsync((time) {
      final retry = SafeReadRetry();
      var calls = 0;
      http.Response? result;
      retry.run(() async => http.Response('failure ${++calls}', 503)).then((r) => result = r);
      time.elapse(const Duration(seconds: 2));
      expect(calls, 3);
      expect(result?.body, 'failure 3');
      retry.close();
    });
  });

  for (final failure in [
    TimeoutException('timeout'),
    const SocketException('disconnected'),
    http.ClientException('connection reset'),
  ]) {
    test('${failure.runtimeType} is retried twice and then preserved', () {
      fakeAsync((time) {
        final retry = SafeReadRetry();
        var calls = 0;
        Object? error;
        retry
            .run(() async {
              calls++;
              throw failure;
            })
            .then<void>((_) => fail('Expected failure'), onError: (Object e) => error = e);
        time.elapse(const Duration(seconds: 2));
        expect(calls, 3);
        expect(error, same(failure));
        retry.close();
      });
    });
  }

  for (final status in [200, 302, 400, 401, 403, 404]) {
    test('HTTP $status is returned without a retry', () async {
      final retry = SafeReadRetry();
      addTearDown(retry.close);
      var calls = 0;
      expect(
        (await retry.run(() async {
          calls++;
          return http.Response('', status);
        })).statusCode,
        status,
      );
      expect(calls, 1);
    });
  }

  for (final header in ['2', HttpDate.format(DateTime(2030))]) {
    test('Retry-After $header delays the next attempt and disposal interrupts it', () {
      fakeAsync((time) {
        final retry = SafeReadRetry();
        var calls = 0;
        Object? error;
        retry
            .run(() async {
              calls++;
              return http.Response('', 429, headers: {'retry-after': header});
            })
            .then<void>((_) => fail('Expected cancellation'), onError: (Object e) => error = e);
        time.elapse(const Duration(milliseconds: 1900));
        expect(calls, 1);
        retry.close();
        time.flushMicrotasks();
        expect(error, isA<http.RequestAbortedException>());
        time.elapse(const Duration(seconds: 10));
        expect(calls, 1);
        expect(time.nonPeriodicTimerCount, 0);
        expect(time.periodicTimerCount, 0);
      });
    });
  }

  test('scope change during backoff cancels without another request', () {
    fakeAsync((time) {
      final retry = SafeReadRetry();
      var active = true, calls = 0;
      Object? error;
      RequestScope.run(
        () => active,
        () => retry.run(() async {
          calls++;
          return http.Response('', 503);
        }),
      ).then<void>((_) => fail('Expected cancellation'), onError: (Object e) => error = e);
      time.flushMicrotasks();
      active = false;
      time.elapse(const Duration(seconds: 1));
      expect(error, isA<http.RequestAbortedException>());
      expect(calls, 1);
      retry.close();
    });
  });

  test('an aborted attempt is never retried', () async {
    final retry = SafeReadRetry();
    addTearDown(retry.close);
    var calls = 0;
    await expectLater(
      retry.run(() async {
        calls++;
        throw http.RequestAbortedException();
      }),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(calls, 1);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/notifications/data/api_notification_repository.dart';
import 'package:vanta/features/notifications/domain/notification_status.dart';

import '../../support/vanta_api.dart';
import '../../support/push_device.dart';

import 'package:vanta/features/notifications/data/push_api_repository.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';

class Transport extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final responses = <Completer<http.StreamedResponse>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    unawaited(request.finalize().drain<void>());
    final response = Completer<http.StreamedResponse>();
    responses.add(response);
    return response.future;
  }

  @override
  void close() {}
}

Future<void> turn() => Future<void>.delayed(Duration.zero);
Matcher cause(ApiErrorCause cause) =>
    isA<VantaApiFailure>().having((e) => e.details?.cause, 'cause', cause);

Future<VantaApiSessionRepository> session(
  Transport transport, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final store = MemoryStore()
    ..value = VantaApiCredentials(
      address: vantaTestAddress.toLowerCase(),
      accessToken: 'access',
      refreshToken: 'refresh',
      accessExpiresAt: vantaTestNow.add(const Duration(hours: 1)),
    );
  final result = VantaApiSessionRepository(
    http: VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: transport, timeout: timeout),
    store: store,
    signer: () => KeySigner(),
    relyingParty: Uri.https('app.vanta.exchange'),
    now: () => vantaTestNow,
  );
  await result.restore(vantaTestAddress);
  return result;
}

void main() {
  for (final operationName in [
    'inbox read',
    'read marker',
    'push register',
    'push unregister',
    'push prefs',
    'push status',
  ]) {
    for (final headers in [false, true]) {
      test(
        '$operationName cancellation aborts ${headers ? 'body' : 'headers'} and preserves another consumer',
        () async {
          final transport = Transport(), api = await session(transport);
          addTearDown(api.close);
          final repository = ApiNotificationRepository(api);
          var current = true, cancelled = false;
          Future<void> operation() async {
            switch (operationName) {
              case 'inbox read':
                await repository.read(category: NotificationFilter.all, unreadOnly: false);
              case 'read marker':
                await repository.markRead(idempotencyKey: 'one-operation');
              case 'push register':
                await PushApiRepository(api).register(
                  const PushDeviceRegistration(
                    metadata: pushMetadata,
                    token: 'token',
                    locale: 'en',
                    utcOffsetMinutes: 480,
                  ),
                  idempotencyKey: 'register-once',
                );
              case 'push unregister':
                await PushApiRepository(api).unregister('token', idempotencyKey: 'unregister-once');
              case 'push prefs':
                await PushApiRepository(api).updatePreferences(
                  PushPreferencesUpdate(categories: {PushCategory.fills: false}),
                  idempotencyKey: 'prefs-once',
                );
              case 'push status':
                await PushApiRepository(api).status();
            }
          }

          final request = RequestScope.runOwned(() => current, operation);
          final failure = expectLater(request, throwsA(cause(ApiErrorCause.cancelled)));
          await turn();
          final other = api.get('/other');
          await turn();
          final body = StreamController<List<int>>(onCancel: () => cancelled = true);
          if (headers) {
            transport.responses[0].complete(http.StreamedResponse(body.stream, 200));
            body.add(utf8.encode('{'));
            await turn();
          }
          current = false;
          await failure;
          expect((transport.requests[0] as http.Abortable).abortTrigger, completes);
          if (headers) expect(cancelled, isTrue);
          if (!headers) {
            transport.responses[0].complete(http.StreamedResponse(body.stream, 200));
          }
          transport.responses[1].complete(
            http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200),
          );
          expect(await other, {'ok': true});
          await turn();
          await body.close();
        },
      );
    }
  }
  for (final headers in [false, true]) {
    test('read marker timeout aborts ${headers ? 'body' : 'headers'} without replay', () async {
      final transport = Transport(),
          api = await session(transport, timeout: const Duration(milliseconds: 80));
      addTearDown(api.close);
      final request = ApiNotificationRepository(api).markRead(idempotencyKey: 'same');
      final failure = expectLater(request, throwsA(cause(ApiErrorCause.timeout)));
      await turn();
      final body = StreamController<List<int>>();
      if (headers) transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
      await failure;
      expect((transport.requests.single as http.Abortable).abortTrigger, completes);
      expect(transport.requests, hasLength(1));
      if (!headers) transport.responses.single.complete(http.StreamedResponse(body.stream, 200));
      await turn();
      await body.close();
    });
  }
  test(
    'cancelling a notification during shared refresh leaves another reader authorized',
    () async {
      final transport = Transport();
      final store = MemoryStore()
        ..value = VantaApiCredentials(
          address: vantaTestAddress.toLowerCase(),
          accessToken: 'expired',
          refreshToken: 'old-refresh',
          accessExpiresAt: vantaTestNow.subtract(const Duration(seconds: 1)),
        );
      final shared = VantaApiSessionRepository(
        http: VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: transport),
        store: store,
        signer: () => KeySigner(),
        relyingParty: Uri.https('app.vanta.exchange'),
        now: () => vantaTestNow,
      );
      addTearDown(shared.close);
      await shared.restore(vantaTestAddress);
      var current = true, aborted = false;
      final marker = RequestScope.runOwned(
        () => current,
        () => ApiNotificationRepository(shared).markRead(idempotencyKey: 'read-once'),
      );
      final failure = expectLater(marker, throwsA(cause(ApiErrorCause.cancelled)));
      await turn();
      final other = shared.get('/statistics');
      await turn();
      expect(transport.requests.single.url.path, '/v1/auth/refresh');
      (transport.requests.single as http.Abortable).abortTrigger!.then((_) => aborted = true);
      current = false;
      await failure;
      expect(aborted, isFalse);
      transport.responses[0].complete(
        http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(issued('rotated', 'next-refresh')))),
          200,
        ),
      );
      for (var i = 0; i < 5; i++) {
        await turn();
      }
      expect(transport.requests.map((r) => r.url.path), ['/v1/auth/refresh', '/statistics']);
      expect(transport.requests[1].headers['Authorization'], 'Bearer rotated');
      transport.responses[1].complete(
        http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200),
      );
      expect(await other, {'ok': true});
      expect(store.value!.refreshToken, 'next-refresh');
    },
  );

  test('inactive ownership cancels before transport dispatch', () async {
    final transport = Transport(), api = await session(transport);
    addTearDown(api.close);
    await expectLater(
      RequestScope.runOwned(
        () => false,
        () => ApiNotificationRepository(api).markRead(idempotencyKey: 'cancelled'),
      ),
      throwsA(cause(ApiErrorCause.cancelled)),
    );
    expect(transport.requests, isEmpty);
  });
  test('session disposal aborts an in-flight marker without automatic replay', () async {
    final transport = Transport(), api = await session(transport);
    final request = ApiNotificationRepository(api).markRead(idempotencyKey: 'once');
    final failure = expectLater(request, throwsA(cause(ApiErrorCause.cancelled)));
    await turn();
    api.close();
    await failure;
    expect(transport.requests, hasLength(1));
    transport.responses.single.complete(http.StreamedResponse(const Stream.empty(), 200));
    await turn();
  });
}

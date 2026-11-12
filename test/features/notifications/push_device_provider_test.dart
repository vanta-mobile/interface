import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/localization/locale_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/notifications/application/push_device_provider.dart';
import 'package:vanta/features/notifications/application/push_messaging_provider.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';
import 'package:vanta/features/notifications/domain/push_registration.dart';

import '../../support/api_notifications.dart';
import '../../support/push_device.dart';
import '../../support/vanta_api.dart';

void main() {
  late InboxFixture f;
  late DevicePushRepository native;
  PushDeviceController controller() => f.container.read(pushDeviceProvider.notifier);
  PushDeviceState state() => f.container.read(pushDeviceProvider);
  Future<void> start({bool stored = true}) async {
    native = DevicePushRepository();
    f = InboxFixture(messaging: native, storedSession: stored);
    f.backend.routes['POST /v1/push/register'] = (_) =>
        json({'registered': true, 'device_id': 3, 'status': 'full'});
    f.backend.routes['POST /v1/push/unregister'] = (_) =>
        json({'removed': 1, 'status': 'inbox_only'});
    f.backend.routes['GET /v1/push/status'] = (_) => json(pushStatusJson());
    f.container.listen(pushDeviceProvider, (_, _) {});
    await f.settle();
  }

  tearDown(() async {
    f.dispose();
    await native.changes.close();
  });
  test('binds a native token to a restored session without another wallet signature', () async {
    await start();
    expect(state().bound, isTrue);
    expect(f.signer.calls, 0);
    final request = f.backend.requests.singleWhere((r) => r.url.path == '/v1/push/register');
    final body = jsonDecode(request.body) as Map;
    expect(body['token'], 'fcm-token-one');
    expect(body['app_id'], 'exchange.vanta.app');
    expect(body['utcOffsetMinutes'], 480);
    expect(request.headers['Authorization'], 'Bearer stored');
    await controller().refresh();
    expect(f.backend.paths.where((p) => p == 'POST /v1/push/register'), hasLength(1));
  });
  test('waits for explicit sign-in instead of signing to register a device', () async {
    await start(stored: false);
    expect(state().bound, isFalse);
    expect(f.signer.calls, 0);
    expect(f.backend.paths, isNot(contains('POST /v1/push/register')));
    await f.container.read(vantaApiSessionProvider.notifier).ensure();
    await f.settle();
    expect(state().bound, isTrue);
    expect(f.signer.calls, 1);
  });
  test('token rotation removes the old token before binding the replacement', () async {
    await start();
    native.changes.add('fcm-token-two');
    await f.settle();
    final writes = f.backend.requests
        .where((r) => r.url.path.startsWith('/v1/push/') && r.method == 'POST')
        .toList();
    expect(writes.map((r) => r.url.path), [
      '/v1/push/register',
      '/v1/push/unregister',
      '/v1/push/register',
    ]);
    expect(jsonDecode(writes[1].body), {'token': 'fcm-token-one'});
    expect((jsonDecode(writes[2].body) as Map)['token'], 'fcm-token-two');
    expect(state().bound, isTrue);
  });
  test('permission withdrawal unbinds and never registers an unauthorized refresh token', () async {
    await start();
    native.value = const PushRegistration(permission: PushPermission.denied);
    f.container.invalidate(pushRegistrationProvider);
    await f.settle();
    expect(state().bound, isFalse);
    expect(f.backend.paths.last, 'GET /v1/push/status');
    native.changes.add('should-not-bind');
    await f.settle();
    expect(f.backend.paths.where((p) => p == 'POST /v1/push/register'), hasLength(1));
    expect(f.backend.paths.where((p) => p == 'POST /v1/push/unregister'), hasLength(1));
  });
  test('explicit unbind remains paused until a new bind action', () async {
    await start();
    await controller().unbind();
    final count = f.backend.paths.where((p) => p == 'POST /v1/push/register').length;
    await controller().refresh();
    expect(state().bound, isFalse);
    expect(f.backend.paths.where((p) => p == 'POST /v1/push/register'), hasLength(count));
    await controller().bind();
    expect(state().bound, isTrue);
  });
  test('metadata changes register current locale and UTC offset without token churn', () async {
    await start();
    f.utcOffset = -300;
    await controller().refresh();
    await f.container.read(localeProvider.notifier).select('zh');
    await f.settle();
    final requests = f.backend.requests.where((r) => r.url.path == '/v1/push/register').toList();
    expect(requests, hasLength(3));
    expect((jsonDecode(requests.last.body) as Map)['utcOffsetMinutes'], -300);
    expect((jsonDecode(requests.last.body) as Map)['locale'], 'zh');
    expect(f.backend.paths, isNot(contains('POST /v1/push/unregister')));
  });
  test('native registration failure still fetches the server visibility warning', () async {
    await start();
    native.error = StateError('native registration unavailable');
    f.backend.routes['GET /v1/push/status'] = (_) =>
        json(pushStatusJson(status: 'no_server_visibility'));
    f.container.invalidate(pushRegistrationProvider);
    await f.settle();
    expect(state().error, isNotNull);
    expect(state().status!.capability, PushCapability.noServerVisibility);
  });

  test('a failed binding retry retains its idempotency key and safe server failure', () async {
    await start();
    await controller().unbind();
    f.backend.routes['POST /v1/push/register'] = (_) =>
        json({'code': 'internal_error', 'message': 'Push gateway unavailable'}, 503);
    await controller().bind();
    expect(state().error, isNotNull);
    expect(state().bound, isFalse);
    final first = f.backend.requests.lastWhere((r) => r.url.path == '/v1/push/register');
    f.backend.routes['POST /v1/push/register'] = (_) =>
        json({'registered': true, 'device_id': 3, 'status': 'full'});
    await controller().refresh();
    final last = f.backend.requests.lastWhere((r) => r.url.path == '/v1/push/register');
    expect(first.headers['Idempotency-Key'], last.headers['Idempotency-Key']);
    expect(state().bound, isTrue);
  });
  test('logout revokes the server session and clears capability and token ownership', () async {
    await start();
    f.backend.routes['POST /v1/auth/logout'] = (_) => json({'ok': true});
    f.auth.setWallet(null);
    await f.settle();
    expect(state().bound, isFalse);
    expect(state().status, isNull);
    expect(f.store.value, isNull);
    expect(f.backend.paths, contains('POST /v1/auth/logout'));
    expect(f.backend.paths.where((p) => p == 'POST /v1/push/unregister'), isEmpty);
  });
  test(
    'a late registration cannot update another wallet or unregister using its session',
    () async {
      await start();
      await controller().unbind();
      final gate = Completer<void>();
      f.backend.routes['POST /v1/push/register'] = (_) async {
        await gate.future;
        return json({'registered': true, 'device_id': 9, 'status': 'full'});
      };
      final pending = controller().bind();
      await f.settle();
      f.auth.setWallet('0x${'ab' * 20}');
      await f.settle();
      await pending;
      expect(state().bound, isFalse);
      expect(state().status, isNull);
      gate.complete();
      await f.settle();
      expect(state().status, isNull);
      expect(f.signer.calls, 0);
      expect(
        f.backend.requests
            .lastWhere((r) => r.url.path == '/v1/auth/logout')
            .headers['Authorization'],
        'Bearer stored',
      );
    },
  );
  test('a new login waits for previous session logout before restoring or signing', () async {
    await start();
    final gate = Completer<void>();
    f.backend.routes['POST /v1/auth/logout'] = (_) async {
      await gate.future;
      return json({'ok': true});
    };
    f.auth.setWallet(null);
    await f.settle();
    f.auth.setWallet(vantaTestAddress);
    await f.settle();
    final signIn = f.container.read(vantaApiSessionProvider.notifier).ensure();
    await f.settle();
    expect(f.signer.calls, 0);
    expect(state().bound, isFalse);
    gate.complete();
    await signIn;
    await f.settle();
    expect(f.signer.calls, 1);
    expect(state().bound, isTrue);
    final logout = f.backend.paths.indexOf('POST /v1/auth/logout');
    final nonce = f.backend.paths.indexOf('GET /v1/auth/nonce');
    expect(nonce, greaterThan(logout));
  });

  test('preference patch is typed, serialized and refreshes resulting status', () async {
    await start();
    final gate = Completer<void>();
    var active = 0, maxActive = 0;
    f.backend.routes['POST /v1/push/prefs'] = (_) async {
      active++;
      if (active > maxActive) maxActive = active;
      await gate.future;
      active--;
      return json({'fills': false});
    };
    final first = controller().updatePreferences(
      PushPreferencesUpdate(categories: {PushCategory.fills: false}),
    );
    final second = controller().updatePreferences(
      PushPreferencesUpdate(minNotional: Decimal.parse('10.5')),
    );
    await f.settle();
    expect(active, 1);
    expect(state().busy, isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(maxActive, 1);
    expect(state().busy, isFalse);
    expect(f.backend.requests.where((r) => r.url.path == '/v1/push/prefs'), hasLength(2));
  });
}

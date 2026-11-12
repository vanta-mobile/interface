import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/notifications/data/push_api_repository.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';

import '../../support/api_notifications.dart';
import '../../support/push_device.dart';
import '../../support/vanta_api.dart';

void main() {
  late InboxFixture f;
  late PushApiRepository repository;
  setUp(() async {
    f = InboxFixture();
    await f.start();
    repository = PushApiRepository(f.repository);
  });
  tearDown(() => f.dispose());
  test(
    'register sends platform token and installed app metadata with offset and idempotency',
    () async {
      f.backend.routes['POST /v1/push/register'] = (_) => json({
        'registered': true,
        'device_id': 7,
        'status': 'full',
        'quiet_hours_need_offset': false,
      });
      final result = await repository.register(
        const PushDeviceRegistration(
          metadata: pushMetadata,
          token: 'actual-fcm',
          locale: 'zh',
          utcOffsetMinutes: 480,
        ),
        idempotencyKey: 'stable',
      );
      expect(result.deviceId, 7);
      expect(result.capability, PushCapability.full);
      expect(jsonDecode(f.backend.requests.last.body), {
        'platform': 'android',
        'token': 'actual-fcm',
        'app_id': 'exchange.vanta.app',
        'app_version': '0.0.2',
        'locale': 'zh',
        'utcOffsetMinutes': 480,
      });
      expect(f.backend.requests.last.headers['Idempotency-Key'], 'stable');
    },
  );
  test('iOS registration uses explicit APNs environment', () async {
    f.backend.routes['POST /v1/push/register'] = (_) =>
        json({'registered': true, 'device_id': 1, 'status': 'inbox_only'});
    await repository.register(
      const PushDeviceRegistration(
        metadata: PushDeviceMetadata(
          platform: PushPlatform.ios,
          appId: 'exchange.vanta.app',
          appVersion: '1',
          environment: PushEnvironment.sandbox,
        ),
        token: 'apns',
        locale: 'en',
        utcOffsetMinutes: -300,
      ),
      idempotencyKey: 'ios',
    );
    final body = jsonDecode(f.backend.requests.last.body) as Map;
    expect(body['token'], 'apns');
    expect(body['environment'], 'sandbox');
    expect(body['platform'], 'ios');
  });
  test('unregister accepts an already absent device', () async {
    f.backend.routes['POST /v1/push/unregister'] = (_) =>
        json({'removed': 0, 'status': 'inbox_only'});
    await repository.unregister('old-token', idempotencyKey: 'remove');
    expect(jsonDecode(f.backend.requests.last.body), {'token': 'old-token'});
  });
  test('preference changes send only changed fields and preserve decimal threshold', () async {
    f.backend.routes['POST /v1/push/prefs'] = (_) => json({
      'fills': false,
      'min_notional': '0.000000000000000001',
      'quiet_start': '22:00',
      'quiet_end': '07:00',
      'quiet_timezone': 'device',
    });
    final prefs = await repository.updatePreferences(
      PushPreferencesUpdate(
        categories: {PushCategory.fills: false},
        quietStart: '22:00',
        quietEnd: '07:00',
        minNotional: Decimal.parse('0.000000000000000001'),
      ),
      idempotencyKey: 'prefs',
    );
    final body = jsonDecode(f.backend.requests.last.body) as Map;
    expect(body, {
      'fills': false,
      'quiet_start': '22:00',
      'quiet_end': '07:00',
      'min_notional': '0.000000000000000001',
    });
    expect(prefs.minNotional, Decimal.parse('0.000000000000000001'));
    expect(prefs.categories.containsKey(PushCategory.transfers), isFalse);
    expect(PushCategory.values.map((e) => e.name), isNot(contains('liquidation')));
  });
  test('invalid quiet intervals, empty changes and negative thresholds fail before transport', () {
    expect(() => PushPreferencesUpdate(), throwsFormatException);
    expect(() => PushPreferencesUpdate(quietStart: '22:00'), throwsFormatException);
    expect(
      () => PushPreferencesUpdate(quietStart: '24:00', quietEnd: '07:00'),
      throwsFormatException,
    );
    expect(
      () => PushPreferencesUpdate(quietStart: '07:00', quietEnd: '07:00:00'),
      throwsFormatException,
    );
    expect(() => PushPreferencesUpdate(minNotional: Decimal.parse('-1')), throwsFormatException);
  });
  test('status preserves capability and unknown optional preferences', () async {
    f.backend.routes['GET /v1/push/status'] = (_) =>
        json({...pushStatusJson(status: 'no_server_visibility', devices: 0), 'reason': '-5052'});
    final result = await repository.status();
    expect(result.capability, PushCapability.noServerVisibility);
    expect(result.reason, '-5052');
    expect(result.preferences.minNotional, isNull);
    expect(result.preferences.categories, isEmpty);
  });
  test('malformed backend states reject without defaulting to full delivery', () async {
    for (final body in [
      pushStatusJson(status: 'unknown'),
      {...pushStatusJson(), 'devices': -1},
      {
        ...pushStatusJson(),
        'prefs': {'fills': 'true'},
      },
      {
        ...pushStatusJson(),
        'prefs': {'quiet_start': '22:00'},
      },
      {
        ...pushStatusJson(),
        'prefs': {'min_notional': 'NaN'},
      },
    ]) {
      f.backend.routes['GET /v1/push/status'] = (_) => json(body);
      await expectLater(repository.status(), throwsA(isA<VantaApiFailure>()));
    }
  });
  test('session refresh replays a device write with the same body and idempotency key', () async {
    var attempts = 0;
    f.backend.routes['POST /v1/push/unregister'] = (_) => ++attempts == 1
        ? json({'code': 'session_expired', 'message': 'Expired'}, 401)
        : json({'removed': 1});
    f.backend.routes['POST /v1/auth/refresh'] = (_) => json(issued('new', 'refresh-next'));
    await repository.unregister('old-token', idempotencyKey: 'same');
    final requests = f.backend.requests.where((r) => r.url.path == '/v1/push/unregister').toList();
    expect(requests, hasLength(2));
    expect(requests.first.body, requests.last.body);
    expect(requests.map((r) => r.headers['Idempotency-Key']), everyElement('same'));
  });
}

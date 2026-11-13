import 'package:decimal/decimal.dart';

import '../../../core/errors/api_error_parser.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/push_device.dart';

class PushApiRepository {
  PushApiRepository(this.session);
  final VantaApiSessionRepository session;
  Future<PushStatus> status() async {
    final json = await session.get('/v1/push/status');
    return _validated(() {
      final devices = _count(json['devices']);
      final prefs = json['prefs'];
      if (prefs is! Map<String, Object?>) throw const FormatException('prefs');
      return PushStatus(
        capability: _capability(json['status']),
        devices: devices,
        preferences: mapPushPreferences(prefs),
        reason: _optionalText(json['reason']),
        note: safeApiMessage(json['note']),
      );
    });
  }

  Future<PushRegisterResult> register(
    PushDeviceRegistration registration, {
    required String idempotencyKey,
  }) async {
    final metadata = registration.metadata;
    if (registration.token.trim().isEmpty ||
        metadata.appId.isEmpty ||
        metadata.platform == PushPlatform.ios && metadata.environment == null ||
        registration.utcOffsetMinutes.abs() > 14 * 60) {
      throw const VantaApiFailure(vantaApiDataInvalid);
    }
    final json = await session.postIdempotent(
      '/v1/push/register',
      idempotencyKey: idempotencyKey,
      body: {
        'platform': metadata.platform.name,
        'token': registration.token,
        'app_id': metadata.appId,
        if (metadata.platform == PushPlatform.ios) 'environment': metadata.environment!.name,
        'locale': registration.locale,
        'app_version': metadata.appVersion,
        'utcOffsetMinutes': registration.utcOffsetMinutes,
      },
    );
    return _validated(() {
      if (json['registered'] != true ||
          json['quiet_hours_need_offset'] != null && json['quiet_hours_need_offset'] is! bool) {
        throw const FormatException('register');
      }
      return PushRegisterResult(
        deviceId: _count(json['device_id']),
        capability: _capability(json['status']),
        quietHoursNeedOffset: json['quiet_hours_need_offset'] == true,
      );
    });
  }

  Future<void> unregister(String token, {required String idempotencyKey}) async {
    if (token.trim().isEmpty) throw const VantaApiFailure(vantaApiDataInvalid);
    final json = await session.postIdempotent(
      '/v1/push/unregister',
      body: {'token': token},
      idempotencyKey: idempotencyKey,
    );
    _validated(() {
      if (json['removed'] != null) _count(json['removed']);
      if (json['status'] != null) _capability(json['status']);
    });
  }

  Future<PushPreferences> updatePreferences(
    PushPreferencesUpdate update, {
    required String idempotencyKey,
  }) async {
    final json = await session.postIdempotent(
      '/v1/push/prefs',
      idempotencyKey: idempotencyKey,
      body: {
        for (final e in update.categories.entries) e.key.name: e.value,
        if (update.quietStart != null || update.clearQuietHours) 'quiet_start': update.quietStart,
        if (update.quietEnd != null || update.clearQuietHours) 'quiet_end': update.quietEnd,
        if (update.minNotional != null) 'min_notional': update.minNotional.toString(),
      },
    );
    return _validated(() => mapPushPreferences(json));
  }
}

PushPreferences mapPushPreferences(Map<String, Object?> json) {
  final start = _optionalText(json['quiet_start']), end = _optionalText(json['quiet_end']);
  if ((start == null) != (end == null) ||
      start != null && (!validPushTime(start) || !validPushTime(end!)) ||
      json['quiet_timezone'] != null && json['quiet_timezone'] != 'device') {
    throw const FormatException('quiet hours');
  }
  final raw = json['min_notional'];
  Decimal? minimum;
  if (raw != null) {
    if (raw is! String || raw.length > 80 || !RegExp(r'^\d+(\.\d+)?$').hasMatch(raw)) {
      throw const FormatException('minimum');
    }
    minimum = Decimal.parse(raw);
  }
  return PushPreferences(
    categories: {
      for (final category in PushCategory.values)
        if (json.containsKey(category.name)) category: _boolean(json[category.name]),
    },
    quietStart: start,
    quietEnd: end,
    minNotional: minimum,
  );
}

T _validated<T>(T Function() read) {
  try {
    return read();
  } on FormatException {
    throw const VantaApiFailure(vantaApiDataInvalid);
  }
}

PushCapability _capability(Object? value) => switch (value) {
  'full' => PushCapability.full,
  'inbox_only' => PushCapability.inboxOnly,
  'no_server_visibility' => PushCapability.noServerVisibility,
  _ => throw const FormatException('capability'),
};
int _count(Object? value) =>
    value is int && value >= 0 ? value : throw const FormatException('count');
bool _boolean(Object? value) => value is bool ? value : throw const FormatException('boolean');
String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 4096) throw const FormatException('text');
  return value;
}

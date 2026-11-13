import 'package:decimal/decimal.dart';

enum PushCapability { full, inboxOnly, noServerVisibility }

enum PushCategory { fills, triggers, orders, funding, transfers, announcements }

enum PushPlatform { ios, android }

enum PushEnvironment { sandbox, production }

class PushDeviceMetadata {
  const PushDeviceMetadata({
    required this.platform,
    required this.appId,
    required this.appVersion,
    this.environment,
  });
  final PushPlatform platform;
  final String appId, appVersion;
  final PushEnvironment? environment;
}

class PushDeviceRegistration {
  const PushDeviceRegistration({
    required this.metadata,
    required this.token,
    required this.locale,
    required this.utcOffsetMinutes,
  });
  final PushDeviceMetadata metadata;
  final String token, locale;
  final int utcOffsetMinutes;
}

class PushPreferences {
  PushPreferences({
    Map<PushCategory, bool> categories = const {},
    this.quietStart,
    this.quietEnd,
    this.minNotional,
  }) : categories = Map.unmodifiable(categories);

  /// Missing optional fields remain unknown rather than becoming enabled/zero.
  final Map<PushCategory, bool> categories;
  final String? quietStart, quietEnd;
  final Decimal? minNotional;
}

class PushPreferencesUpdate {
  PushPreferencesUpdate({
    Map<PushCategory, bool> categories = const {},
    this.quietStart,
    this.quietEnd,
    this.minNotional,
    this.clearQuietHours = false,
  }) : categories = Map.unmodifiable(categories) {
    if ((quietStart == null) != (quietEnd == null) ||
        clearQuietHours && quietStart != null ||
        quietStart != null &&
            (!validPushTime(quietStart!) ||
                !validPushTime(quietEnd!) ||
                _seconds(quietStart!) == _seconds(quietEnd!)) ||
        minNotional != null && minNotional! < Decimal.zero ||
        categories.isEmpty && quietStart == null && minNotional == null && !clearQuietHours) {
      throw const FormatException('push preferences');
    }
  }
  final Map<PushCategory, bool> categories;
  final String? quietStart, quietEnd;
  final Decimal? minNotional;

  /// Sends explicit `null` quiet hours to switch them off.
  final bool clearQuietHours;
}

bool validPushTime(String value) =>
    RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$').hasMatch(value);
int _seconds(String value) {
  final parts = value.split(':').map(int.parse).toList();
  return parts[0] * 3600 + parts[1] * 60 + (parts.length == 3 ? parts[2] : 0);
}

class PushStatus {
  const PushStatus({
    required this.capability,
    required this.devices,
    required this.preferences,
    this.reason,
    this.note,
  });
  final PushCapability capability;
  final int devices;
  final PushPreferences preferences;
  final String? reason, note;
}

class PushRegisterResult {
  const PushRegisterResult({
    required this.deviceId,
    required this.capability,
    required this.quietHoursNeedOffset,
  });
  final int deviceId;
  final PushCapability capability;
  final bool quietHoursNeedOffset;
}

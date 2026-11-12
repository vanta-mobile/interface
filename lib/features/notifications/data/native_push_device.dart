import 'package:flutter/services.dart';

import '../../../core/vanta_api/vanta_api_failure.dart';
import '../domain/push_device.dart';

/// Native metadata comes from the installed app and its signing configuration,
/// including the APNs environment. No package/bundle ID is guessed in Dart.
Future<PushDeviceMetadata> readNativePushDevice() async {
  final Map<Object?, Object?>? json;
  try {
    json = await const MethodChannel('exchange.vanta.app/push')
        .invokeMapMethod<Object?, Object?>('device');
  } on PlatformException {
    throw const VantaApiFailure(vantaApiRequestFailed);
  } on MissingPluginException {
    throw const VantaApiFailure(vantaApiUnavailable);
  }
  final platform = switch (json?['platform']) {
    'ios' => PushPlatform.ios,
    'android' => PushPlatform.android,
    _ => null,
  };
  final environment = switch (json?['environment']) {
    'sandbox' => PushEnvironment.sandbox,
    'production' => PushEnvironment.production,
    _ => null,
  };
  final appId = json?['app_id'], version = json?['app_version'];
  if (platform == null ||
      appId is! String ||
      appId.isEmpty ||
      version is! String ||
      version.isEmpty ||
      platform == PushPlatform.ios && environment == null) {
    throw const VantaApiFailure(vantaApiDataInvalid);
  }
  return PushDeviceMetadata(
    platform: platform,
    appId: appId,
    appVersion: version,
    environment: environment,
  );
}

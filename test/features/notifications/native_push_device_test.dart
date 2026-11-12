import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/notifications/data/native_push_device.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('exchange.vanta.app/push');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('iOS environment is read from native signing metadata, not debug mode guesses', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'platform': 'ios',
        'app_id': 'exchange.vanta.app',
        'app_version': '1.2.3',
        'environment': 'production',
      },
    );
    final metadata = await readNativePushDevice();
    expect(metadata.environment, PushEnvironment.production);
    expect(metadata.appId, 'exchange.vanta.app');
  });
  test('missing iOS environment rejects registration rather than assuming production', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {'platform': 'ios', 'app_id': 'exchange.vanta.app', 'app_version': '1'},
    );
    await expectLater(readNativePushDevice(), throwsA(isA<VantaApiFailure>()));
  });
  test('unsupported platform cannot send an Android token by default', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {'platform': 'web', 'app_id': 'test', 'app_version': '1'},
    );
    await expectLater(readNativePushDevice(), throwsA(isA<VantaApiFailure>()));
  });
}

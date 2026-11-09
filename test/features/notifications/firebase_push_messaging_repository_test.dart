import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/firebase_push_messaging_repository.dart';
import 'package:vanta/features/notifications/domain/push_registration.dart';

void main() {
  late TestMessaging messaging;
  setUp(() => messaging = TestMessaging());
  tearDown(() => messaging.ids.close());

  test('requests undetermined permission and registers with FCM', () async {
    final repository = FirebasePushMessagingRepository(messaging, isIOS: false);
    final id = repository.registrationChanges.first;
    final registration = await repository.register();
    expect(registration.permission, PushPermission.authorized);
    expect(await id, 'test-installation-id');
    expect(messaging.permissionRequests, 1);
    expect(messaging.registrations, 1);
    expect(messaging.apnsRequests, 0);
  });

  test('denied permission never registers or prompts again', () async {
    messaging.status = AuthorizationStatus.denied;
    final registration = await FirebasePushMessagingRepository(messaging, isIOS: false).register();
    expect(registration.permission, PushPermission.denied);
    expect(registration.installationId, isNull);
    expect(messaging.permissionRequests, 0);
    expect(messaging.registrations, 0);
  });

  test('declining the initial prompt preserves denied state', () async {
    messaging.requestedStatus = AuthorizationStatus.denied;
    final registration = await FirebasePushMessagingRepository(messaging, isIOS: false).register();
    expect(registration.canReceive, isFalse);
    expect(messaging.permissionRequests, 1);
    expect(messaging.registrations, 0);
  });

  test('permanent denial stays distinct and never registers or prompts', () async {
    messaging.status = AuthorizationStatus.deniedPermanently;
    final registration = await FirebasePushMessagingRepository(messaging, isIOS: false).register();
    expect(registration.permission, PushPermission.deniedPermanently);
    expect(registration.installationId, isNull);
    expect(messaging.permissionRequests, 0);
    expect(messaging.registrations, 0);
  });

  test('iOS waits for APNs and accepts a later registration', () async {
    messaging.status = AuthorizationStatus.authorized;
    messaging.apnsToken = null;
    final repository = FirebasePushMessagingRepository(messaging, isIOS: true);
    final registration = await repository.register();
    expect(registration.permission, PushPermission.authorized);
    expect(registration.installationId, isNull);
    expect(messaging.registrations, 0);
    expect(messaging.foregroundEnabled, isTrue);
    final id = repository.registrationChanges.first;
    messaging.ids.add('');
    messaging.ids.add('later-installation-id');
    expect(await id, 'later-installation-id');
  });

  test('iOS provisional authorization uses APNs without prompting again', () async {
    messaging.status = AuthorizationStatus.provisional;
    final registration = await FirebasePushMessagingRepository(messaging, isIOS: true).register();
    expect(registration.permission, PushPermission.provisional);
    expect(registration.installationId, isNull);
    expect(messaging.registrations, 1);
    expect(messaging.apnsRequests, 1);
    expect(messaging.permissionRequests, 0);
  });

  test('empty registration IDs are filtered out', () async {
    final repository = FirebasePushMessagingRepository(messaging, isIOS: false);
    final id = repository.registrationChanges.first;
    messaging.ids.add('   ');
    messaging.ids.add('valid-id');
    expect(await id, 'valid-id');
  });

  test('registration failures remain observable to Riverpod', () async {
    messaging.registrationFailure = StateError('registration unavailable');
    await expectLater(
      FirebasePushMessagingRepository(messaging, isIOS: false).register(),
      throwsStateError,
    );
  });
}

class TestMessaging implements FirebaseMessaging {
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  AuthorizationStatus requestedStatus = AuthorizationStatus.authorized;
  String? apnsToken = 'test-apns-token';
  Object? registrationFailure;
  int permissionRequests = 0, registrations = 0, apnsRequests = 0;
  bool foregroundEnabled = false;
  final ids = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get onRegistered => ids.stream;

  @override
  Future<NotificationSettings> getNotificationSettings() async => settings(status);

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionRequests++;
    status = requestedStatus;
    return settings(status);
  }

  @override
  Future<String?> getAPNSToken() async {
    apnsRequests++;
    return apnsToken;
  }

  @override
  Future<void> register({String? vapidKey, String? serviceWorkerScriptPath}) async {
    registrations++;
    if (registrationFailure != null) throw registrationFailure!;
    ids.add('test-installation-id');
  }

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {
    foregroundEnabled = alert && badge && sound;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationSettings settings(AuthorizationStatus status) => NotificationSettings(
  authorizationStatus: status,
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.disabled,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

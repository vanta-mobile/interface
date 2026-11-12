import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import '../domain/push_registration.dart';

/// Let FCM/the OS display background notification payloads. Financial state
/// always comes from authenticated API reads, never from push contents.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<PushMessagingRepository?> initializeFirebaseMessaging() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return FirebasePushMessagingRepository(
      FirebaseMessaging.instance,
      isIOS: defaultTargetPlatform == TargetPlatform.iOS,
    );
  } catch (_) {
    // Push setup must not prevent access to the trading app. Do not log SDK
    // errors, payloads, registration identifiers, or native stack traces.
    debugPrint('Firebase Messaging initialization failed; push notifications are unavailable.');
    return null;
  }
}

class FirebasePushMessagingRepository implements PushMessagingRepository {
  FirebasePushMessagingRepository(this._messaging, {required this.isIOS});

  final FirebaseMessaging _messaging;
  final bool isIOS;

  @override
  Stream<String> get registrationChanges =>
      // The Vanta contract uses APNs/FCM tokens, not Firebase Installation IDs.
      // ignore: deprecated_member_use
      _messaging.onTokenRefresh
          .asyncMap((fcmToken) async => isIOS ? await _messaging.getAPNSToken() : fcmToken)
          .where((token) => token != null && token.trim().isNotEmpty)
          .cast<String>();

  @override
  Future<PushRegistration> register() async {
    var settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await _messaging.requestPermission();
    }
    final permission = switch (settings.authorizationStatus) {
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.deniedPermanently => PushPermission.deniedPermanently,
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
    };
    final registration = PushRegistration(permission: permission);
    if (!registration.canReceive) return registration;

    if (isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // APNs may arrive later; token refresh or app resume retries the lookup.
      final token = await _messaging.getAPNSToken();
      return PushRegistration(permission: permission, token: token);
    }
    // This backend requires the legacy FCM token rather than the new FID API.
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    return PushRegistration(permission: permission, token: token);
  }
}

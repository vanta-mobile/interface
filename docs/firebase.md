# Firebase Cloud Messaging

Vanta uses Firebase project **`vanta-a7de4`** (display name `vanta`). Only the
Android and iOS applications are registered; no web application is configured.

| Platform | Package / Bundle ID | Firebase App ID | Native configuration |
| --- | --- | --- | --- |
| Android | `exchange.vanta.app` | `1:908368200337:android:5f63754010b288ae327530` | `android/app/google-services.json` |
| iOS | `exchange.vanta.app` | `1:908368200337:ios:8b22057ec8e8e843327530` | `ios/Runner/GoogleService-Info.plist` |

`lib/firebase_options.dart` contains the matching generated Dart configuration.
These Firebase client configuration files contain public application identifiers
and client API keys. They are not service account credentials. APNs private keys,
service account JSON, and Firebase CLI login credentials must remain outside the
repository and application bundle.

## Client behavior

- Dependencies: `firebase_core` 5.1.0 and `firebase_messaging` 17.0.1, recorded in
  `pubspec.lock`. Android applies the Google Services Gradle plugin. iOS bundles
  its plist, enables Push Notifications and remote-notification background mode,
  and keeps Firebase's default AppDelegate swizzling enabled.
- Native startup initializes Firebase and registers a release-safe, top-level
  background handler. An initialization failure leaves the trading app usable.
- `VantaApp` observes `pushRegistrationProvider`. Its repository requests the
  native permission dialog only when authorization is undetermined; a denied
  permission does not prompt again automatically. Authorized and provisional
  registrations are supported. No custom permission screen is added.
- Messaging 17 uses `register()` / `onRegistered` and a **Firebase Installation
  ID (FID)**. Both native platforms opt in to installation ID registration. This
  integration does not mix FID registration with the deprecated `getToken()` /
  `onTokenRefresh` APIs. The immutable Riverpod state contains `permission` and
  `installationId`; subscribe to it when implementing an authenticated backend
  registration contract. Identifiers are not printed or persisted by Vanta.
- Subscribe before registering so a native registration event during startup is
  retained. Empty IDs are discarded, refresh errors preserve existing data, and
  replacing or disposing the provider cancels its listener. iOS waits for an APNs
  token before explicit FCM registration; a later automatic registration event
  supplies the FID.
- With notification permission and platform push services available, **background
  notification payloads** use the operating system's notification UI. iOS also
  enables foreground alert, badge, and sound presentation. Android foreground
  messages do not display a banner automatically; local foreground notifications
  are outside this SDK configuration change. Notification taps open the app's
  normal entry screen; no new deep-link destination is configured.
- Data-only background messages currently initialize Firebase and perform no
  business work. No push payload is interpreted as an order, transfer, wallet
  identity, or authenticated inbox entry. Existing Aster/local inbox behavior is
  unchanged. There is no backend endpoint, wallet/FID association, topic
  subscription, or server-side push sender in this change.
- Tests and previews use the default absent repository and never initialize
  Firebase or trigger native permission dialogs.

## iOS APNs setup and verification

The owner reports that the APNs key has been uploaded to Firebase. The remote
key configuration and delivery have not been independently verified. Confirm the
App ID capability and provisioning profiles below before testing iOS delivery;
key creation/upload steps are retained for reference and future replacement:

1. In Apple Developer → Certificates, Identifiers & Profiles → Identifiers,
   enable **Push Notifications** for the explicit App ID `exchange.vanta.app`.
2. Create an APNs authentication key (or use an existing suitable key). Keep the
   `.p8` private. Record its Key ID and Apple Team ID.
3. In [Firebase project settings → Cloud Messaging](https://console.firebase.google.com/project/vanta-a7de4/settings/cloudmessaging),
   select the iOS app and upload the key under **APNs Authentication Key**, with
   its Key ID and Team ID. A valid APNs certificate is an alternative.
4. Regenerate development/distribution provisioning profiles with Push
   Notifications enabled. Update `IOS_PROVISIONING_PROFILE_BASE64` for CI if an
   old profile is configured. Debug uses `aps-environment=development`;
   Profile/Release use `production`. The release script validates production
   APNs entitlements in both the distribution profile and exported app.
5. Build and sign on macOS/Xcode, launch on a suitable iOS device, allow
   notifications, and verify registration and foreground/background delivery.

Android requires Google Play services and access to Firebase messaging endpoints.
An Android emulator must include Google APIs / Google Play. Allow notifications
on Android 13 and later. Notification delivery on devices without these services
is not provided by this integration.

## Reconfigure and verify

The checked-in client configuration is sufficient for normal builds; CI does not
need Firebase CLI login or a service account just to compile the app. To refresh
the generated configuration:

```sh
firebase login
dart pub global activate flutterfire_cli
dart pub global run flutterfire_cli:flutterfire configure \
  --project=vanta-a7de4 --platforms=android,ios \
  --android-package-name=exchange.vanta.app \
  --ios-bundle-id=exchange.vanta.app
```

On Linux, FlutterFire may omit the iOS native plist/project wiring. Fetch the
plist explicitly if needed and preserve its Runner Resources entry, signing
entitlements, and native installation ID settings:

```sh
firebase apps:sdkconfig IOS 1:908368200337:ios:8b22057ec8e8e843327530 \
  --project=vanta-a7de4 --out ios/Runner/GoogleService-Info.plist
```

Acceptance requires a launched device with native permission granted and a
nonempty FID in `pushRegistrationProvider`. Inspect the state locally using a
debugger; do not log the ID. Use a trusted backend compatible with FID targeting
to send a harmless notification and verify foreground/background handling and
tap-to-open. Do not pass an FID to an API field that expects a legacy FCM token.
This work does not send notifications or register private account subscriptions.

References: [Flutter setup](https://firebase.google.com/docs/flutter/setup),
[FCM client and FID registration](https://firebase.google.com/docs/cloud-messaging/flutter/client),
[message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive).

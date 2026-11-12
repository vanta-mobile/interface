import 'dart:async';

import 'package:vanta/features/notifications/domain/push_registration.dart';
import 'package:vanta/features/notifications/domain/push_device.dart';

class DevicePushRepository implements PushMessagingRepository {
  PushRegistration value = const PushRegistration(
    permission: PushPermission.authorized,
    token: 'fcm-token-one',
  );
  final changes = StreamController<String>.broadcast(sync: true);
  int calls = 0;
  Object? error;
  @override
  Future<PushRegistration> register() async {
    calls++;
    if (error != null) throw error!;
    return value;
  }

  @override
  Stream<String> get registrationChanges => changes.stream;
}

const pushMetadata = PushDeviceMetadata(
  platform: PushPlatform.android,
  appId: 'exchange.vanta.app',
  appVersion: '0.0.2',
);
Map<String, Object?> pushStatusJson({
  String status = 'full',
  int devices = 1,
  Map<String, Object?> prefs = const {},
}) => {'status': status, 'devices': devices, 'prefs': prefs};

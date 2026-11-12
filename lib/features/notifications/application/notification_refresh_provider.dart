import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_notification_provider.dart';
import 'push_device_provider.dart';

/// All API data displayed by the inbox settles before its refresh ends.
final notificationPageRefreshProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await Future.wait([
      ref.read(apiNotificationInboxProvider.notifier).refresh(),
      ref.read(pushDeviceProvider.notifier).refresh(),
    ]);
  },
);

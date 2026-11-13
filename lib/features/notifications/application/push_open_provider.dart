import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../deep_link/application/deep_link_provider.dart';
import '../data/push_open_source.dart';
import '../domain/api_notification.dart';
import '../domain/push_notification_open.dart';
import 'api_notification_provider.dart';

/// Null when push messaging is unavailable; `main` provides the Firebase one.
final pushOpenSourceProvider = Provider<PushOpenSource?>((ref) => null);

/// Routes tapped notifications through the deep-link path and queues the
/// mark-read. Watched from app start so a launching tap is not lost.
final pushOpenRouterProvider = Provider<void>((ref) {
  final source = ref.watch(pushOpenSourceProvider);
  if (source == null) return;
  ref.onDispose(() => unawaited(source.close()));
  source.start((data) {
    final open = PushNotificationOpen.fromData(data);
    ref.read(deepLinkInboxProvider.notifier).deliver(open.link);
    if (open.read case final target?) {
      ref.read(pushNotificationReadProvider.notifier).request(target, owner: open.owner);
    }
  });
});

typedef PushReadRequest = ({ApiNotificationReadTarget target, String? owner});

/// A mark-read waiting for the owning wallet's API session. A cold start or a
/// sign-in may come first; another wallet's session drops the request, so a
/// tap never marks an entry for a different account.
final pushNotificationReadProvider = NotifierProvider<PushNotificationRead, PushReadRequest?>(
  PushNotificationRead.new,
);

class PushNotificationRead extends Notifier<PushReadRequest?> {
  @override
  PushReadRequest? build() {
    ref.listen(vantaApiSessionProvider, (_, _) => _attempt());
    ref.listen(authProvider.select((s) => s.identity?.walletAddress), (_, _) => _attempt());
    return null;
  }

  void request(ApiNotificationReadTarget target, {String? owner}) {
    state = (target: target, owner: owner);
    _attempt();
  }

  void _attempt() {
    final pending = state;
    if (pending == null) return;
    final session = ref.read(vantaApiSessionProvider);
    final wallet = ref.read(authProvider).identity?.walletAddress?.toLowerCase();
    // Wait out restoring, signing and wallet switches.
    if (!session.ready || wallet == null || session.address != wallet) return;
    state = null;
    if (pending.owner != null && pending.owner != wallet) return;
    unawaited(ref.read(apiNotificationInboxProvider.notifier).markReadTarget(pending.target));
  }
}

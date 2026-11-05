import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/domain/spot_history.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/local_notification_repository.dart';
import '../data/notification_units_repository.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/domain/aster_account.dart';
import '../domain/account_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final repository = LocalNotificationRepository(LocalNotificationStorage());
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final notificationInboxProvider = NotifierProvider<NotificationInboxController, InboxSnapshot>(
  NotificationInboxController.new,
);

class NotificationInboxController extends Notifier<InboxSnapshot> {
  @override
  InboxSnapshot build() {
    final repository = ref.watch(notificationRepositoryProvider);
    final subscription = repository.changes.listen((value) {
      if (ref.mounted) state = value;
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(repository.reload());
    return repository.snapshot;
  }

  Future<void> ingest(String authorizedAddress, AccountNotification event) =>
      ref.read(notificationRepositoryProvider).add(authorizedAddress, event);
  Future<void> retry() => ref.read(notificationRepositoryProvider).reload();
  Future<void> markRead({String? key}) async {
    final address = ref.read(authProvider).identity?.walletAddress;
    if (address != null) await ref.read(notificationRepositoryProvider).markRead(address, key: key);
  }
}

final walletNotificationsProvider = Provider<List<InboxEntry>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress?.toLowerCase()));
  final entries = ref.watch(notificationInboxProvider).entries;
  if (address == null) return const [];
  return List.unmodifiable(entries.where((e) => e.address == address));
});

final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(walletNotificationsProvider).where((e) => !e.read).length,
);

final notificationUnitsRepositoryProvider = Provider<NotificationUnitsRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return AsterNotificationUnitsRepository(service);
});
final notificationUnitsProvider = FutureProvider<Map<String, AsterContractUnits>>(
  (ref) => ref.watch(notificationUnitsRepositoryProvider).read(),
);

final spotNotificationUnitsRepositoryProvider = Provider<SpotNotificationUnitsRepository>((ref) {
  final service = AsterSpotService();
  ref.onDispose(service.close);
  return AsterSpotNotificationUnitsRepository(service);
});
final spotNotificationUnitsProvider = FutureProvider<Map<String, SpotSymbolUnits>>(
  (ref) => ref.watch(spotNotificationUnitsRepositoryProvider).read(),
);

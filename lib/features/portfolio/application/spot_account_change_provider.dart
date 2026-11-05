import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../notifications/application/notification_provider.dart';
import '../data/aster_spot_service.dart';
import '../data/signed_account_change_repository.dart';
import '../domain/account_change_stream.dart';
import 'account_change_provider.dart' show accountChangeClockProvider;
import 'account_read_provider.dart';
import 'spot_account_provider.dart';
import 'spot_history_provider.dart';
import 'wallet_stream_controller.dart';
import 'spot_open_orders_provider.dart';

final spotAccountChangeRepositoryProvider = Provider<AccountChangeRepository>((ref) {
  final service = AsterSpotService();
  final repository = SignedAccountChangeRepository.spot(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(accountChangeClockProvider),
  );
  ref.onDispose(() {
    repository.clear();
    service.close();
  });
  return repository;
});
final spotAccountChangeProvider = NotifierProvider<SpotAccountChangeController, AccountChangeState>(
  SpotAccountChangeController.new,
);

class SpotAccountChangeController extends WalletStreamController {
  @override
  AccountChangeRepository get repository => ref.read(spotAccountChangeRepositoryProvider);
  @override
  DateTime get now => ref.read(accountChangeClockProvider)();
  @override
  void invalidateSnapshots() {
    ref.read(spotAccountReadProvider.notifier).markStale();
    ref.read(spotHistoryProvider.notifier).markStale();
    ref.read(spotOpenOrdersProvider.notifier).markStale();
  }

  @override
  void applyEvent(String authorizedAddress, AccountChangeEvent event) {
    if (event.spotOrder case final update?) {
      ref.read(spotOpenOrdersProvider.notifier).applyEvent(update);
    }
    if (event.notification case final notification?) {
      unawaited(
        ref.read(notificationInboxProvider.notifier).ingest(authorizedAddress, notification),
      );
    }
  }
}

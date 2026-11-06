import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../funding/application/transfer_history_provider.dart';
import '../../notifications/application/notification_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_account_change_repository.dart';
import '../domain/account_change_stream.dart';
import '../domain/account_update_book.dart';
import '../domain/account_snapshot.dart';
import 'account_read_provider.dart';
import 'wallet_stream_controller.dart';
import 'open_orders_provider.dart';
import 'position_adl_provider.dart';
import 'position_risk_provider.dart';

final accountChangeClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final accountChangeRepositoryProvider = Provider<AccountChangeRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  final repository = SignedAccountChangeRepository(
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

/// Once explicitly enabled, monitoring survives navigation until stopped,
/// expired or the identity changes. It never signs or reads REST automatically.
final accountChangeProvider = NotifierProvider<AccountChangeController, AccountChangeState>(
  AccountChangeController.new,
);

class AccountChangeController extends WalletStreamController {
  @override
  AccountChangeRepository get repository => ref.read(accountChangeRepositoryProvider);
  @override
  DateTime get now => ref.read(accountChangeClockProvider)();
  @override
  void invalidateSnapshots() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(positionAdlProvider.notifier).markStale();
  }

  @override
  void applyEvent(String authorizedAddress, AccountChangeEvent event) {
    if (event.notification case final notification?) {
      unawaited(
        ref.read(notificationInboxProvider.notifier).ingest(authorizedAddress, notification),
      );
    }
    if (event.account case final update?) {
      if ({'DEPOSIT', 'WITHDRAW', 'WITHDRAW_REJECT'}.contains(update.reason)) {
        ref.read(transferHistoryProvider.notifier).markRefreshNeeded();
      }
      try {
        ref.read(accountReadProvider.notifier).applyEvent(update);
        ref.read(positionRiskProvider.notifier).applyEvent(update);
      } on AccountEventsFull {
        throw const AccountReadFailure('accountEventsCapacity');
      } on FormatException {
        throw const AccountReadFailure('accountDataInvalid');
      }
    }
    if (event.order case final order?) {
      try {
        ref.read(openOrdersReadProvider.notifier).applyEvent(order);
      } on FormatException {
        throw const AccountReadFailure('orderEventsCapacity');
      }
    }
  }
}

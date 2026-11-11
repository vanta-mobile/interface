import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/order_recovery_journal.dart';
import '../data/signed_order_query_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/order_recovery.dart';
import 'account_read_provider.dart' show asterReadNoncesProvider;

// main injects the durable file journal before rendering the app. Previews and
// tests embed the same application with an isolated in-memory journal.
final orderRecoveryJournalProvider = Provider<OrderRecoveryJournal>((ref) {
  final journal = MemoryOrderRecoveryJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final orderRecoverySnapshotProvider =
    NotifierProvider<OrderRecoverySnapshotController, OrderRecoverySnapshot>(
      OrderRecoverySnapshotController.new,
    );

class OrderRecoverySnapshotController extends Notifier<OrderRecoverySnapshot> {
  @override
  OrderRecoverySnapshot build() {
    final journal = ref.watch(orderRecoveryJournalProvider);
    final subscription = journal.changes.listen((value) {
      if (ref.mounted) state = value;
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return journal.snapshot;
  }

  Future<void> retry() async {
    try {
      await ref.read(orderRecoveryJournalProvider).reload();
    } on AccountReadFailure {
      /* Journal publishes a diagnostic storage error. */
    }
  }
}

final pendingWalletOrdersProvider = Provider<List<OrderRecoveryRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress?.toLowerCase()));
  return ref
      .watch(orderRecoverySnapshotProvider)
      .records
      .where((r) => r.query.address.toLowerCase() == address)
      .toList(growable: false);
});
final orderRecoveryRepositoryProvider = Provider<OrderRecoveryRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedOrderQueryRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    ref.watch(asterReadNoncesProvider),
    DateTime.now,
    journal: ref.watch(orderRecoveryJournalProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

class OrderRecoveryCheck {
  const OrderRecoveryCheck({
    this.record,
    this.result,
    this.failure,
    this.step = LiveOrderStep.idle,
  });
  final OrderRecoveryRecord? record;
  final LiveOrderResult? result;
  final AccountReadFailure? failure;
  final LiveOrderStep step;
  bool get busy => step != LiveOrderStep.idle;
}

final orderRecoveryProvider = NotifierProvider<OrderRecoveryController, OrderRecoveryCheck>(
  OrderRecoveryController.new,
);

class OrderRecoveryController extends Notifier<OrderRecoveryCheck> {
  int _revision = 0;
  @override
  OrderRecoveryCheck build() {
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (a, b) {
        if (a != b) {
          _revision++;
          state = const OrderRecoveryCheck();
        }
      },
    );
    ref.onDispose(() => _revision++);
    return const OrderRecoveryCheck();
  }

  Future<void> query(String key) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    final record = ref.read(pendingWalletOrdersProvider).where((r) => r.key == key).singleOrNull;
    if (state.busy || auth.busy || identity?.signingAvailable != true || record == null) {
      return;
    }
    final revision = ++_revision;
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity?.id == identity!.id &&
        ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
            record.query.address.toLowerCase() &&
        ref.read(authProvider).identity?.signingAvailable == true;
    state = OrderRecoveryCheck(record: record, step: LiveOrderStep.preparing);
    try {
      final result = await ref
          .read(orderRecoveryRepositoryProvider)
          .query(
            record.query,
            isCurrent: current,
            onStep: (step) {
              if (current()) state = OrderRecoveryCheck(record: record, step: step);
            },
          );
      if (!current()) return;
      state = OrderRecoveryCheck(record: record, result: result);
    } catch (error) {
      if (current()) {
        state = OrderRecoveryCheck(
          record: record,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
    }
  }
}

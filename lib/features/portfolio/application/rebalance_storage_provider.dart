import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/rebalance_journal.dart';
import '../domain/asset_rebalance.dart';

final rebalanceJournalProvider = Provider<RebalanceJournal>((ref) {
  final journal = MemoryRebalanceJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final rebalanceStorageProvider = NotifierProvider<RebalanceStorageController, RebalanceStorage>(
  RebalanceStorageController.new,
);

class RebalanceStorageController extends Notifier<RebalanceStorage> {
  @override
  RebalanceStorage build() {
    final journal = ref.watch(rebalanceJournalProvider);
    final sub = journal.changes.listen((s) {
      if (ref.mounted) state = s;
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(rebalanceJournalProvider).reload();
    } catch (_) {
      /* Published blocking error. */
    }
  }
}

final pendingRebalancesProvider = Provider<List<RebalanceRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(rebalanceStorageProvider)
      .records
      .where((r) => r.address.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});

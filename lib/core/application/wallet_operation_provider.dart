import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_operation_journal.dart';
import '../domain/wallet_operation.dart';
import '../../features/auth/application/auth_provider.dart';

final walletOperationJournalProvider = Provider<WalletOperationJournal>((ref) {
  final journal = MemoryWalletOperationJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final walletOperationStorageProvider =
    NotifierProvider<WalletOperationStorageController, WalletOperationStorage>(
      WalletOperationStorageController.new,
    );

class WalletOperationStorageController extends Notifier<WalletOperationStorage> {
  @override
  WalletOperationStorage build() {
    final journal = ref.watch(walletOperationJournalProvider),
        sub = journal.changes.listen((s) {
          if (ref.mounted) state = s;
        });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(walletOperationJournalProvider).reload();
    } catch (_) {}
  }
}

final currentWalletOperationsProvider = Provider<List<WalletOperationRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(walletOperationStorageProvider)
      .records
      .where((r) => r.address.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});

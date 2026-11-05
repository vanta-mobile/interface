import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wallet_operation_journal.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';

final positionMarginJournalProvider = Provider<WalletOperationJournal>((ref) {
  final journal = MemoryWalletOperationJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final positionMarginStorageProvider =
    NotifierProvider<PositionMarginStorageController, WalletOperationStorage>(
      PositionMarginStorageController.new,
    );

class PositionMarginStorageController extends Notifier<WalletOperationStorage> {
  @override
  WalletOperationStorage build() {
    final journal = ref.watch(positionMarginJournalProvider);
    final sub = journal.changes.listen((s) {
      if (ref.mounted) state = s;
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(positionMarginJournalProvider).reload();
    } catch (_) {}
  }
}

final currentPositionMarginsProvider = Provider<List<WalletOperationRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(positionMarginStorageProvider)
      .records
      .where((r) => r.address.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/internal_transfer_journal.dart';
import '../domain/internal_transfer.dart';

final internalTransferJournalProvider = Provider<InternalTransferJournal>((ref) {
  final journal = MemoryInternalTransferJournal();
  ref.onDispose(() => unawaited(journal.close()));
  return journal;
});
final internalTransferStorageProvider =
    NotifierProvider<InternalTransferStorageController, InternalTransferStorage>(
      InternalTransferStorageController.new,
    );

class InternalTransferStorageController extends Notifier<InternalTransferStorage> {
  @override
  InternalTransferStorage build() {
    final journal = ref.watch(internalTransferJournalProvider);
    final sub = journal.changes.listen((s) {
      if (ref.mounted) state = s;
    });
    ref.onDispose(() => unawaited(sub.cancel()));
    return journal.snapshot;
  }

  Future<void> reload() async {
    try {
      await ref.read(internalTransferJournalProvider).reload();
    } catch (_) {
      /* Published blocking error. */
    }
  }
}

final pendingInternalTransfersProvider = Provider<List<InternalTransferRecord>>((ref) {
  final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
  return ref
      .watch(internalTransferStorageProvider)
      .records
      .where((r) => r.address.toLowerCase() == address?.toLowerCase())
      .toList(growable: false);
});

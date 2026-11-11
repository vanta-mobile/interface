import '../../funding/application/internal_transfer_storage_provider.dart';
import '../../funding/presentation/internal_transfer_entry.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/order_recovery_provider.dart';
import 'order_recovery_screen.dart';
import 'rebalance_entry.dart';
import '../application/rebalance_storage_provider.dart';

class OrderRecoveryNotice extends ConsumerWidget {
  const OrderRecoveryNotice({super.key, this.showOrders = true});
  final bool showOrders;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(orderRecoverySnapshotProvider);
    final pending = ref.watch(pendingWalletOrdersProvider);
    final rebalanceStorage = ref.watch(rebalanceStorageProvider);
    final rebalancePending = ref.watch(pendingRebalancesProvider);
    final transferStorage = ref.watch(internalTransferStorageProvider),
        transferPending = ref.watch(pendingInternalTransfersProvider);
    final ordersNeedRecovery =
        showOrders && (!storage.ready || storage.failure != null || pending.isNotEmpty);
    if (!ordersNeedRecovery &&
        rebalanceStorage.ready &&
        !rebalanceStorage.failure &&
        rebalancePending.isEmpty &&
        transferStorage.ready &&
        !transferStorage.failure &&
        transferPending.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RebalanceRecoveryNotice(),
          const InternalTransferRecoveryNotice(),
          if (ordersNeedRecovery) ...[
            Text(
              storage.failure != null ? l10n.orderRecoveryStorage : l10n.orderRecoveryPending,
              style: const TextStyle(color: AppColors.warning),
            ),
            TextButton(
              onPressed: () => openOrderRecovery(context),
              child: Text(l10n.orderRecoveryTitle),
            ),
          ],
        ],
      ),
    );
  }
}

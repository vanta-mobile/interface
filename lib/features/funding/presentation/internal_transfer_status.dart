import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/internal_transfer_provider.dart';
import '../application/internal_transfer_storage_provider.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_form.dart';

class InternalTransferRecovery extends ConsumerWidget {
  const InternalTransferRecovery({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(internalTransferStorageProvider),
        pending = ref.watch(pendingInternalTransfersProvider),
        state = ref.watch(internalTransferProvider),
        l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!storage.ready || storage.failure) ...[
          Text(l10n.internalTransferStorage, style: const TextStyle(color: AppColors.warning)),
          TextButton(
            key: const Key('internal-transfer-storage-retry'),
            onPressed: ref.read(internalTransferStorageProvider.notifier).reload,
            child: Text(l10n.notificationRetry),
          ),
        ],
        for (final record in pending) InternalTransferRecordPanel(record: record, pending: true),
        if (pending.isEmpty && state.record?.reply != null)
          InternalTransferRecordPanel(record: state.record!, pending: false),
      ],
    );
  }
}

class InternalTransferRecordPanel extends StatelessWidget {
  const InternalTransferRecordPanel({super.key, required this.record, required this.pending});
  final InternalTransferRecord record;
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), r = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          !pending
              ? l10n.internalTransferReported
              : r.reply == null
              ? l10n.internalTransferUnknown
              : l10n.internalTransferReplyPending,
        ),
        Text(internalTransferDirectionLabel(l10n, r.direction)),
        SelectableText('${r.amount} ${r.asset}'),
        Text(l10n.internalTransferClientId),
        SelectableText(r.clientId),
        Text(l10n.rebalanceNonce),
        SelectableText('${r.nonce}'),
        Text(r.preparedAt.toUtc().toIso8601String()),
        if (r.reply != null) ...[
          Text(l10n.internalTransferTransactionId),
          SelectableText(r.reply!.transactionId),
        ],
      ],
    );
  }
}

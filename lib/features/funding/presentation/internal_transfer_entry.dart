import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/internal_transfer_storage_provider.dart';
import 'internal_transfer_screen.dart';

void openInternalTransfer(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const InternalTransferScreen()));

class InternalTransferEntry extends StatelessWidget {
  const InternalTransferEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('internal-transfer-entry'),
    onPressed: () => openInternalTransfer(context),
    icon: const Icon(Icons.swap_vert),
    label: Text(AppLocalizations.of(context).internalTransferTitle),
  );
}

class InternalTransferRecoveryNotice extends ConsumerWidget {
  const InternalTransferRecoveryNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(internalTransferStorageProvider),
        pending = ref.watch(pendingInternalTransfersProvider),
        l10n = AppLocalizations.of(context);
    if (storage.ready && !storage.failure && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          storage.ready && !storage.failure
              ? l10n.internalTransferPending
              : l10n.internalTransferStorage,
          style: const TextStyle(color: AppColors.warning),
        ),
        TextButton(
          key: const Key('internal-transfer-recovery-entry'),
          onPressed: () => openInternalTransfer(context),
          child: Text(l10n.internalTransferTitle),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/rebalance_storage_provider.dart';
import 'rebalance_screen.dart';

void openRebalance(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const RebalanceScreen()));

class RebalanceEntry extends StatelessWidget {
  const RebalanceEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const Key('rebalance-entry'),
    onPressed: () => openRebalance(context),
    child: Text(AppLocalizations.of(context).rebalanceTitle),
  );
}

class RebalanceRecoveryNotice extends ConsumerWidget {
  const RebalanceRecoveryNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(rebalanceStorageProvider),
        pending = ref.watch(pendingRebalancesProvider),
        l10n = AppLocalizations.of(context);
    if (storage.ready && !storage.failure && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          storage.ready && !storage.failure ? l10n.rebalancePending : l10n.rebalanceStorage,
          style: const TextStyle(color: AppColors.warning),
        ),
        TextButton(
          key: const Key('rebalance-recovery-entry'),
          onPressed: () => openRebalance(context),
          child: Text(l10n.rebalanceRecovery),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/spot_history_provider.dart';
import '../domain/spot_history.dart';
import 'account_read_controls.dart';
import 'spot_history_filters.dart';
import 'spot_history_results.dart';

void openSpotHistory(BuildContext context, WidgetRef ref, SpotHistoryKind kind) {
  if (ref.read(spotHistoryProvider).busy) return;
  ref.read(spotHistoryProvider.notifier).selectKind(kind);
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const SpotHistoryScreen()));
}

class SpotHistoryScreen extends ConsumerWidget {
  const SpotHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotHistoryProvider);
    final session = ref.watch(authProvider);
    final address = session.identity?.walletAddress;
    final controller = ref.read(spotHistoryProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stopRead();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.historyTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('spot-history-page'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.historyScope),
              if (address != null) ...[
                const SizedBox(height: 12),
                SelectableText(address, key: const Key('history-wallet')),
              ],
              const SizedBox(height: 16),
              TabChoices(
                items: [l10n.historyOrders, l10n.historyTrades, l10n.historyTransactions],
                selected: state.query.kind.index,
                onSelect: (i) => controller.selectKind(SpotHistoryKind.values[i]),
              ),
              const SizedBox(height: 16),
              const SpotHistoryFilters(),
              if (state.query.kind == SpotHistoryKind.orders) ...[
                const SizedBox(height: 12),
                Text(l10n.historyRetention, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              AccountReadControls(
                state: state,
                buttonKey: const Key('read-spot-history'),
                enabled: state.query.validScope,
                initialLabel: l10n.historyRead,
                refreshLabel: l10n.historyRefresh,
                onRead: controller.refresh,
              ),
              if (state.busy)
                OutlinedButton(
                  key: const Key('stop-spot-history'),
                  onPressed: controller.stopRead,
                  child: Text(l10n.historyStop),
                ),
              const SpotHistoryResults(),
            ],
          ),
        ),
      ),
    );
  }
}

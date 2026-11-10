import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_history_provider.dart';
import '../domain/futures_history.dart';
import 'account_read_controls.dart';
import 'futures_history_filters.dart';
import 'futures_history_results.dart';

void openFuturesHistory(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const FuturesHistoryScreen()));

class FuturesHistoryEntry extends StatelessWidget {
  const FuturesHistoryEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('open-futures-history'),
    onPressed: () => openFuturesHistory(context),
    icon: const Icon(Icons.history),
    label: Text(AppLocalizations.of(context).futuresHistoryTitle),
  );
}

class FuturesHistoryScreen extends ConsumerStatefulWidget {
  const FuturesHistoryScreen({super.key});
  @override
  ConsumerState<FuturesHistoryScreen> createState() => _FuturesHistoryScreenState();
}

class _FuturesHistoryScreenState extends ConsumerState<FuturesHistoryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive) ref.read(futuresHistoryProvider.notifier).markStale();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(futuresHistoryProvider),
        controller = ref.read(futuresHistoryProvider.notifier);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final l10n = AppLocalizations.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stopRead();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.futuresHistoryTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('futures-history-page'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.futuresHistoryScope),
              if (address != null) ...[
                const SizedBox(height: 12),
                SelectableText(address, key: const Key('futures-history-wallet')),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in FuturesHistoryKind.values)
                    ChoiceChip(
                      key: Key('futures-history-kind-${kind.name}'),
                      selected: state.query.kind == kind,
                      label: Text(switch (kind) {
                        FuturesHistoryKind.orders => l10n.historyOrders,
                        FuturesHistoryKind.trades => l10n.historyTrades,
                        FuturesHistoryKind.income => l10n.futuresHistoryIncome,
                      }),
                      onSelected: state.busy ? null : (_) => controller.selectKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const FuturesHistoryFilters(),
              if (state.query.kind == FuturesHistoryKind.orders) ...[
                const SizedBox(height: 12),
                Text(l10n.futuresHistoryRetention, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              AccountReadControls(
                failureView: true,
                state: state,
                buttonKey: const Key('read-futures-history'),
                enabled: state.query.valid,
                initialLabel: l10n.historyRead,
                refreshLabel: l10n.historyRefresh,
                onRead: controller.refresh,
              ),
              if (state.busy)
                OutlinedButton(
                  key: const Key('stop-futures-history'),
                  onPressed: controller.stopRead,
                  child: Text(l10n.historyStop),
                ),
              const FuturesHistoryResults(),
            ],
          ),
        ),
      ),
    );
  }
}

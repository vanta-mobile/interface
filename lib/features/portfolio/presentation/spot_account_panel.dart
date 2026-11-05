import '../../funding/presentation/internal_transfer_entry.dart';
import '../../funding/presentation/funding_info_screen.dart';
import '../../funding/domain/transfer_history.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/presentation/transfer_history_screen.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/spot_account_provider.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';
import 'spot_balance_rows.dart';
import '../application/spot_history_provider.dart';
import '../domain/spot_history.dart';
import 'spot_history_screen.dart';
import 'spot_open_orders_screen.dart';

class SpotAccountPanel extends ConsumerWidget {
  const SpotAccountPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final state = ref.watch(spotAccountReadProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.spotAccountTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(l10n.asterAccountScope, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        if (address != null)
          Row(
            children: [
              Expanded(child: SelectableText(address, key: const Key('spot-account-address'))),
              IconButton(
                tooltip: tr(context, 'copyAddress'),
                onPressed: () => Clipboard.setData(ClipboardData(text: address)),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.spotBalanceScope, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              AccountSnapshotStatus(
                state: state,
                timeKey: const Key('spot-snapshot-time'),
                staleKey: const Key('spot-snapshot-stale'),
              ),
              const SizedBox(height: 12),
              AccountReadControls(
                state: state,
                buttonKey: const Key('read-spot-account'),
                onRead: () => ref.read(spotAccountReadProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SpotOpenOrdersEntry(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in SpotHistoryKind.values)
              OutlinedButton(
                key: Key('spot-history-${kind.name}'),
                onPressed: ref.watch(spotHistoryProvider.select((s) => s.busy))
                    ? null
                    : () => openSpotHistory(context, ref, kind),
                child: Text(switch (kind) {
                  SpotHistoryKind.orders => l10n.historyOrders,
                  SpotHistoryKind.trades => l10n.historyTrades,
                  SpotHistoryKind.transactions => l10n.historyTransactions,
                }),
              ),
          ],
        ),
        const FundingInfoEntry(market: TransferMarket.spot),
        const InternalTransferEntry(),
        const TransferHistoryEntry(),
        if (state.account case final account?) ...[
          const SizedBox(height: 24),
          SpotBalanceRows(account: account, accountStale: state.stale),
        ],
      ],
    );
  }
}

import 'futures_history_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/open_orders_provider.dart';
import '../application/order_cancellation_provider.dart';
import 'order_cancellation_controls.dart';
import 'batch_order_cancellation_controls.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';
import 'aster_open_order_card.dart';
import 'open_orders_event_status.dart';
import '../../../core/presentation/status_view.dart';

class AsterOpenOrdersPanel extends ConsumerStatefulWidget {
  const AsterOpenOrdersPanel({super.key});
  @override
  ConsumerState<AsterOpenOrdersPanel> createState() => _AsterOpenOrdersPanelState();
}

class _AsterOpenOrdersPanelState extends ConsumerState<AsterOpenOrdersPanel> {
  bool currentSymbolOnly = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(openOrdersReadProvider);
    final cancellation = ref.watch(orderCancellationProvider);
    final session = ref.watch(authProvider);
    final canCancel =
        session.identity?.signingAvailable == true &&
        !session.busy &&
        !state.busy &&
        !cancellation.busy &&
        !cancellation.needsRecheck;
    final symbol = ref.watch(symbolProvider);
    final all = state.account?.orders;
    final orders = all?.where((order) => !currentSymbolOnly || order.symbol == symbol).toList();
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.asterOpenOrdersTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.asterOpenOrdersScope, style: Theme.of(context).textTheme.bodySmall),
          const OpenOrdersEventStatus(),
          const FuturesHistoryEntry(),
          AccountSnapshotStatus(
            state: state,
            timeKey: const Key('open-orders-snapshot-time'),
            staleKey: const Key('open-orders-snapshot-stale'),
          ),
          const SizedBox(height: 12),
          AccountReadControls(
            state: state,
            buttonKey: const Key('read-open-orders'),
            initialLabel: l10n.openOrdersReadWithWallet,
            refreshLabel: l10n.openOrdersRefreshWithWallet,
            enabled: !cancellation.busy && !cancellation.needsRecheck,
            failureView: true,
            onRead: () => ref.read(openOrdersReadProvider.notifier).refresh(),
          ),
          const OrderCancellationStatus(),
          const BatchOrderCancellationStatus(),
          OutlinedButton(
            key: const Key('cancel-all-open-orders'),
            onPressed: canCancel && orders?.isNotEmpty == true
                ? () => confirmBatchCancellation(
                    context,
                    ref,
                    symbol: currentSymbolOnly ? symbol : null,
                  )
                : null,
            child: Text(currentSymbolOnly ? l10n.batchCancelCurrent : l10n.batchCancelAll),
          ),
          if (all == null)
            Text(l10n.batchCancelReadFirst, style: Theme.of(context).textTheme.bodySmall),
          if (all != null) ...[
            const SizedBox(height: 12),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                key: const Key('open-orders-current-symbol'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.openOrdersCurrentSymbol),
                value: currentSymbolOnly,
                onChanged: (value) => setState(() => currentSymbolOnly = value),
              ),
            ),
            Text(
              l10n.openOrdersCount(orders!.length),
              key: const Key('open-orders-count'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (orders.isEmpty)
              StatusEmptyView(
                key: const Key('open-orders-empty'),
                message: currentSymbolOnly && all.isNotEmpty
                    ? l10n.openOrdersNoCurrentSymbol
                    : l10n.openOrdersEmpty,
              ),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AsterOpenOrderCard(
                  order: order,
                  onCancel: canCancel ? () => confirmOrderCancellation(context, ref, order) : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

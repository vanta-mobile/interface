import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/spot_open_orders_provider.dart';
import '../application/spot_account_change_provider.dart';
import 'account_change_panel.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';
import 'spot_open_order_card.dart';

void openSpotOpenOrders(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const SpotOpenOrdersScreen()));

class SpotOpenOrdersEntry extends StatelessWidget {
  const SpotOpenOrdersEntry({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const Key('spot-open-orders-entry'),
    onPressed: () => openSpotOpenOrders(context),
    child: Text(AppLocalizations.of(context).spotOpenOrdersTitle),
  );
}

class SpotOpenOrdersScreen extends ConsumerWidget {
  const SpotOpenOrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(spotOpenOrdersProvider),
        controller = ref.read(spotOpenOrdersProvider.notifier);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stopRead();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.spotOpenOrdersTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('spot-open-orders-scroll'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.spotOpenOrdersScope),
              if (address != null) SelectableText(address),
              const AccountChangePanel(spot: true),
              AccountReadControls(
                state: state,
                buttonKey: const Key('read-spot-open-orders'),
                initialLabel: l10n.spotOpenOrdersRead,
                refreshLabel: l10n.spotOpenOrdersRefresh,
                enabled: !ref.watch(spotAccountChangeProvider).busy,
                onRead: controller.refresh,
              ),
              if (state.busy)
                TextButton(
                  key: const Key('stop-spot-open-orders'),
                  onPressed: controller.stopRead,
                  child: Text(l10n.historyStop),
                ),
              AccountSnapshotStatus(state: state),
              const _Results(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerStatefulWidget {
  const _Results();
  @override
  ConsumerState<_Results> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<_Results> {
  final _filter = TextEditingController();
  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (_, _) {
      _filter.clear();
      setState(() {});
    });
    final snapshot = ref.watch(spotOpenOrdersProvider.select((s) => s.account)),
        l10n = AppLocalizations.of(context);
    if (snapshot == null) return const SizedBox.shrink();
    final filter = _filter.text.trim().toUpperCase();
    final orders = snapshot.orders
        .where(
          (o) =>
              filter.isEmpty ||
              o.symbol.toUpperCase().contains(filter) ||
              o.orderId.contains(filter) ||
              o.clientOrderId.toUpperCase().contains(filter),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.spotOpenOrdersEvents),
        if (snapshot.lastEventAt != null)
          Text(l10n.openOrdersEventTime(snapshot.lastEventAt!.toUtc().toIso8601String())),
        if (snapshot.unitsUnavailable) Text(l10n.spotOpenOrdersUnits),
        TextField(
          key: const Key('spot-open-orders-filter'),
          controller: _filter,
          decoration: InputDecoration(labelText: l10n.spotOpenOrdersFilter),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.openOrdersCount(orders.length),
          key: const Key('spot-open-orders-count'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (orders.isEmpty)
          Text(
            filter.isEmpty ? l10n.spotOpenOrdersEmpty : l10n.spotOpenOrdersNoMatch,
            key: const Key('spot-open-orders-empty'),
          ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SpotOpenOrderCard(key: ValueKey(order.key), order: order),
          ),
      ],
    );
  }
}

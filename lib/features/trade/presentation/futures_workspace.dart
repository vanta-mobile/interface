import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../portfolio/presentation/aster_open_orders_panel.dart';
import '../../portfolio/presentation/live_order_screen.dart';
import '../../portfolio/presentation/quick_order_panel.dart';
import '../application/navigation_provider.dart';
import '../application/providers.dart';
import 'widgets/candle_chart.dart';
import 'widgets/market_header.dart';
import 'widgets/order_book.dart';
import 'widgets/order_form.dart';
import 'widgets/positions_panel.dart';
import 'widgets/primitives.dart';

class FuturesWorkspace extends ConsumerWidget {
  const FuturesWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('futures-workspace'),
        padding: EdgeInsets.all(constraints.maxWidth >= 1000 ? 16 : 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Column(
              children: [
                const MarketHeader(),
                const SizedBox(height: 8),
                const FuturesWorkspaceTabs(),
                const SizedBox(height: 8),
                Visibility(
                  visible: chart,
                  maintainState: true,
                  child: const Column(
                    children: [CandleChart(), SizedBox(height: 8), QuickOrderPanel()],
                  ),
                ),
                Visibility(visible: !chart, maintainState: true, child: const DemoTradeWorkspace()),
                const SizedBox(height: 8),
                const FuturesAccountSections(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FuturesWorkspaceTabs extends ConsumerWidget {
  const FuturesWorkspaceTabs({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SegmentedButton<bool>(
    key: const Key('trade-workspace-tabs'),
    segments: [
      ButtonSegment(value: true, label: Text(tr(context, 'quickOrderChartTab'))),
      ButtonSegment(value: false, label: Text(tr(context, 'trade'))),
    ],
    selected: {ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart},
    onSelectionChanged: (value) => ref
        .read(futuresWorkspaceTabProvider.notifier)
        .select(value.first ? FuturesWorkspaceTab.chart : FuturesWorkspaceTab.trade),
  );
}

class DemoTradeWorkspace extends StatelessWidget {
  const DemoTradeWorkspace({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 1000
        ? const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: CandleChart()),
              SizedBox(width: 8),
              Expanded(flex: 2, child: OrderBookPanel()),
              SizedBox(width: 8),
              Expanded(flex: 3, child: OrderForm()),
            ],
          )
        : const Column(
            children: [
              CandleChart(),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: OrderBookPanel()),
                  SizedBox(width: 8),
                  Expanded(flex: 6, child: OrderForm()),
                ],
              ),
            ],
          ),
  );
}

class FuturesAccountSections extends ConsumerWidget {
  const FuturesAccountSections({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      OutlinedButton.icon(
        key: const Key('open-live-order'),
        onPressed: () => openLiveOrder(context, ref.read(symbolProvider)),
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: Text(tr(context, 'liveOrderEntry')),
      ),
      Text(tr(context, 'liveOrderEntryHint'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      const PositionsPanel(),
      const SizedBox(height: 12),
      const AsterOpenOrdersPanel(),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/branding/mark.webp', width: 12, height: 12),
          const SizedBox(width: 6),
          Flexible(child: MutedText(tr(context, 'poweredBy'), size: 8)),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}

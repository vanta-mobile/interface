import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/chart_order_book.dart';
export 'widgets/market_header.dart' show FuturesWorkspaceTabs;
import '../../portfolio/presentation/futures_history_screen.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../portfolio/presentation/trade_open_orders_section.dart';
import '../../portfolio/presentation/live_order_screen.dart';
import '../../portfolio/presentation/live_order_status.dart';
import '../../portfolio/presentation/quick_order_panel.dart';
import '../application/navigation_provider.dart';
import '../application/page_refresh_provider.dart';
import '../application/providers.dart';
import 'widgets/candle_chart.dart';
import 'widgets/market_header.dart';
import 'widgets/compact_order_book.dart';
import 'widgets/trade_kline_panel.dart';
import '../../portfolio/presentation/trade_assets_section.dart';
import '../../portfolio/presentation/trade_positions_section.dart';
import '../../portfolio/application/open_orders_provider.dart';
import '../../portfolio/application/open_orders_auto_read_provider.dart';
import '../../portfolio/application/position_risk_provider.dart';
import '../../portfolio/application/positions_auto_read_provider.dart';
import 'trade_theme.dart';
import '../../portfolio/application/automatic_order_refresh_provider.dart';

class FuturesWorkspace extends ConsumerWidget {
  const FuturesWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(automaticOrderRefreshProvider);
    ref.watch(positionRiskAutoReadProvider);
    ref.watch(openOrdersAutoReadProvider);
    final chart = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 1512 ? (constraints.maxWidth - 1480) / 2 : 16.0;
        final page = RefreshIndicator(
          onRefresh: ref.read(pageRefreshProvider).futures,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const Key('futures-workspace'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const MarketHeader(),
                          SizedBox(height: chart ? 20 : 16),
                          Visibility(
                            visible: chart,
                            maintainState: true,
                            child: const Column(
                              children: [
                                CandleChart(flat: true),
                                SizedBox(height: 20),
                                ChartOrderBook(),
                                LiveOrderStatus(compact: true),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: !chart,
                            maintainState: true,
                            child: const TradeOrderWorkspace(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const FuturesAccountSections(),
                  ],
                ),
              ),
            ],
          ),
        );
        // The chart quick-entry bar stays pinned above the navigation and keyboard.
        return Column(
          children: [
            Expanded(child: page),
            if (chart)
              ColoredBox(
                color: TradeColors.background,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
                  child: const QuickOrderPanel(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TradeOrderWorkspace extends ConsumerWidget {
  const TradeOrderWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          fillColor: TradeColors.card,
          labelStyle: TradeTypography.body.copyWith(color: TradeColors.muted),
          hintStyle: TradeTypography.body.copyWith(color: TradeColors.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: theme.textTheme.copyWith(
          bodyLarge: TradeTypography.body,
          bodyMedium: TradeTypography.body,
        ),
      ),
      child: LiveOrderScreen(symbol: ref.watch(symbolProvider), embedded: true),
    );
    final body = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 && MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(children: [form, const SizedBox(height: 20), const CompactOrderBook()]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 147, child: CompactOrderBook()),
            const SizedBox(width: 12),
            Expanded(flex: 202, child: form),
          ],
        );
      },
    );
    if (!ref.watch(tradeKlineVisibleProvider)) return body;
    return Column(children: [const TradeKlinePanel(), const SizedBox(height: 16), body]);
  }
}

class FuturesAccountSections extends ConsumerStatefulWidget {
  const FuturesAccountSections({super.key});
  @override
  ConsumerState<FuturesAccountSections> createState() => _FuturesAccountSectionsState();
}

class _FuturesAccountSectionsState extends ConsumerState<FuturesAccountSections> {
  int tab = 0;

  static String _count(BuildContext context, String label, int? count) =>
      count == null ? label : AppLocalizations.of(context).tradeTabCount(label, count);

  @override
  Widget build(BuildContext context) {
    final openOrders = ref.watch(openOrdersReadProvider.select((s) => s.account?.orders.length));
    final positions = ref.watch(
      positionRiskProvider.select((s) => s.account?.positions.where((p) => !p.balanceOnly).length),
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _AccountTabs(
            items: [
              _count(context, AppLocalizations.of(context).openOrdersTab, openOrders),
              _count(context, tr(context, 'positions'), positions),
              AppLocalizations.of(context).portfolioAssets,
            ],
            selected: tab,
            onSelect: (value) => setState(() => tab = value),
          ),
        ),
        if (tab == 2)
          const TradeAssetsSection()
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: tab == 0 ? const TradeOpenOrdersSection() : const TradePositionsSection(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

/// Account tabs from the Futures design with the history shortcut on the right.
class _AccountTabs extends StatelessWidget {
  const _AccountTabs({required this.items, required this.selected, required this.onSelect});
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: TradeColors.card)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 20),
                    child: Semantics(
                      selected: i == selected,
                      button: true,
                      child: InkWell(
                        key: ValueKey('futures-account-tab-$i'),
                        onTap: () => onSelect(i),
                        child: IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  items[i],
                                  style: TradeTypography.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: i == selected ? TradeColors.text : TradeColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 1,
                                  color: i == selected
                                      ? TradeColors.accent
                                      : TradeColors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('open-futures-history'),
          tooltip: AppLocalizations.of(context).futuresHistoryTitle,
          onPressed: () => openFuturesHistory(context),
          icon: const PortfolioIcon('history.svg', size: 24, color: TradeColors.text),
        ),
      ],
    ),
  );
}

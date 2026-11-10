import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/chart_order_book.dart';
export 'widgets/market_header.dart' show FuturesWorkspaceTabs;
import '../../portfolio/presentation/aster_open_orders_panel.dart';
import '../../portfolio/presentation/live_order_screen.dart';
import '../../portfolio/presentation/quick_order_panel.dart';
import '../application/navigation_provider.dart';
import '../application/page_refresh_provider.dart';
import '../application/providers.dart';
import 'widgets/candle_chart.dart';
import 'widgets/market_header.dart';
import 'widgets/order_book.dart';
import '../../portfolio/presentation/aster_account_panel.dart';
import '../../portfolio/presentation/position_risk_screen.dart';
import 'widgets/primitives.dart';
import 'trade_theme.dart';

class FuturesWorkspace extends ConsumerWidget {
  const FuturesWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: ref.read(pageRefreshProvider).futures,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          key: const Key('futures-workspace'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
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
                        SizedBox(height: 20),
                        QuickOrderPanel(),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: !chart,
                    maintainState: true,
                    child: const TradeOrderWorkspace(),
                  ),
                  const SizedBox(height: 8),
                  const FuturesAccountSections(),
                ],
              ),
            ),
          ),
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 && MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
            children: [form, const SizedBox(height: 20), const OrderBookPanel(compact: true)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(flex: 147, child: OrderBookPanel(compact: true)),
            const SizedBox(width: 12),
            Expanded(flex: 202, child: form),
          ],
        );
      },
    );
  }
}

class FuturesAccountSections extends ConsumerStatefulWidget {
  const FuturesAccountSections({super.key});
  @override
  ConsumerState<FuturesAccountSections> createState() => _FuturesAccountSectionsState();
}

class _FuturesAccountSectionsState extends ConsumerState<FuturesAccountSections> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TabChoices(
          items: [
            tr(context, 'orders'),
            tr(context, 'positions'),
            AppLocalizations.of(context).portfolioAssets,
          ],
          selected: tab,
          underlined: true,
          onSelect: (value) => setState(() => tab = value),
        ),
      ),
      const SizedBox(height: 8),
      switch (tab) {
        0 => const AsterOpenOrdersPanel(),
        1 => const PositionRiskScreen(embedded: true),
        _ => const AsterAccountPanel(),
      },
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

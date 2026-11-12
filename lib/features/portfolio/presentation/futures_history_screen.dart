import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/trading_history.dart';
import 'portfolio_components.dart';
import 'trading_history_results.dart';

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

class FuturesHistoryScreen extends StatefulWidget {
  const FuturesHistoryScreen({super.key});
  @override
  State<FuturesHistoryScreen> createState() => _FuturesHistoryScreenState();
}

class _FuturesHistoryScreenState extends State<FuturesHistoryScreen> {
  TradingHistoryTab tab = TradingHistoryTab.orders;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TradeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                        icon: const PortfolioIcon('history-arrow.svg', size: 24),
                      ),
                      Expanded(child: Text(l.tradingHistoryTitle, style: TradeTypography.heading)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: TradeColors.line),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in TradingHistoryTab.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              selected: item == tab,
                              button: true,
                              child: TextButton(
                                key: Key('history-tab-${item.name}'),
                                onPressed: () => setState(() => tab = item),
                                style: TextButton.styleFrom(
                                  backgroundColor: tab == item
                                      ? TradeColors.sheet
                                      : TradeColors.historyTab,
                                  foregroundColor: tab == item
                                      ? TradeColors.accent
                                      : TradeColors.muted,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: TradeTypography.body,
                                ),
                                child: Text(l.tradingHistoryTab(item.name)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Expanded(
              child: TradingHistoryResults(key: ValueKey(tab), tab: tab),
            ),
          ],
        ),
      ),
    );
  }
}

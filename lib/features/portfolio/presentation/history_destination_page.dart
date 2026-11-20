import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/no_press_feedback.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/trading_history.dart';
import 'trading_history_results.dart';

/// Primary History destination: orders, positions, fills and income ledger.
class HistoryDestinationPage extends StatefulWidget {
  const HistoryDestinationPage({super.key});
  @override
  State<HistoryDestinationPage> createState() => _HistoryDestinationPageState();
}

class _HistoryDestinationPageState extends State<HistoryDestinationPage> {
  TradingHistoryTab tab = TradingHistoryTab.orders;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: PortfolioColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Image.asset('assets/branding/mark.webp', width: 22, height: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.tradingHistoryTitle, style: PointsTypography.header)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HistoryTabs(selected: tab, onChanged: (value) => setState(() => tab = value)),
          ),
          Expanded(
            child: TradingHistoryResults(key: ValueKey(tab), tab: tab),
          ),
        ],
      ),
    );
  }
}

class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({required this.selected, required this.onChanged});
  final TradingHistoryTab selected;
  final ValueChanged<TradingHistoryTab> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PortfolioColors.assetDivider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 20,
          children: [
            for (final item in TradingHistoryTab.values)
              NoPressFeedback(
                child: Semantics(
                  selected: item == selected,
                  button: true,
                  child: InkWell(
                    key: Key('history-tab-${item.name}'),
                    onTap: () => onChanged(item),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              l.tradingHistoryTab(item.name),
                              style: PortfolioTypography.historyTab.copyWith(
                                color: item == selected
                                    ? PortfolioColors.text
                                    : PortfolioColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 1,
                              color: item == selected
                                  ? PortfolioColors.accent
                                  : PortfolioColors.transparent,
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
    );
  }
}

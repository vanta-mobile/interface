import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/aster_account.dart';
import '../domain/trading_history.dart';
import 'aster_open_order_card.dart';
import 'portfolio_components.dart';
import 'trading_history_components.dart';
import 'trading_history_details.dart';

class TradingHistoryPositionCard extends StatefulWidget {
  const TradingHistoryPositionCard({super.key, required this.position, this.units});
  final HistoryPosition position;
  final AsterContractUnits? units;
  @override
  State<TradingHistoryPositionCard> createState() => _TradingHistoryPositionCardState();
}

class _TradingHistoryPositionCardState extends State<TradingHistoryPositionCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.position, u = widget.units, l = AppLocalizations.of(context);
    final color = historyPnlColor(r.realizedPnl);
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: Key('history-expand-${r.key}'),
              onTap: () => setState(() => expanded = !expanded),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.symbol, style: TradeTypography.symbol),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              HistoryTag(
                                r.side == 'LONG' ? l.long : l.short,
                                positive: r.side == 'LONG',
                              ),
                              Text(
                                r.liquidated
                                    ? l.tradingHistoryLiquidated
                                    : r.status == 'closed'
                                    ? l.tradingHistoryClosed
                                    : l.tradingHistoryOpen,
                                style: TradeTypography.tag.copyWith(color: TradeColors.text),
                              ),
                              const HistoryTag(historyPlaceholder, outlined: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    HistoryExpand(expanded: expanded),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TradeColors.sheet,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.tradingHistoryRealizedPnl,
                        style: TradeTypography.body.copyWith(color: TradeColors.secondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        historyUnit(r.realizedPnl, u?.margin, fixed: 2, signed: true),
                        style: TradeTypography.symbol.copyWith(
                          fontSize: 14,
                          height: 20 / 14,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l.tradingHistoryRoe,
                        textAlign: TextAlign.end,
                        style: TradeTypography.body.copyWith(color: TradeColors.secondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(historyPlaceholder, style: TradeTypography.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            HistoryRow(
              l.positionTpslEntryPrice,
              historyAmount(r.inferred ? null : r.entryPrice, fixed: 6),
            ),
            HistoryRow(l.tradingHistoryClosePrice, historyAmount(r.exitPrice, fixed: 6)),
            HistoryRow(l.tradingHistoryMaxHeld, historyUnit(r.maxQuantity, u?.base)),
            HistoryRow(l.tradingHistoryClosed, historyPlaceholder),
            HistoryRow(l.tradingHistoryOpenedAt, historyTime(r.inferred ? null : r.time)),
            HistoryRow(l.tradingHistoryClosedAt, historyTime(r.closedAt)),
            const SizedBox(height: 8),
            OpenOrderChipButton(
              label: l.tradingHistoryDetails,
              key: Key('history-position-details-${r.id}'),
              onPressed: () => showHistoryRelatedOrders(context, r),
            ),
          ],
        ],
      ),
    );
  }
}

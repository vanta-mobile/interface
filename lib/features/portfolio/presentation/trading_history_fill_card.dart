import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/aster_account.dart';
import '../domain/trading_history.dart';
import 'portfolio_components.dart';
import 'trading_history_components.dart';

class TradingHistoryFillCard extends StatelessWidget {
  const TradingHistoryFillCard({super.key, required this.fill, this.units});
  final HistoryFill fill;
  final AsterContractUnits? units;
  @override
  Widget build(BuildContext context) {
    final r = fill, l = AppLocalizations.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.tradingHistoryPerp(r.symbol), style: TradeTypography.symbol),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HistoryTag(historyDirection(l, r.side, r.positionSide), positive: r.side == 'BUY'),
            Text(
              historyTime(r.time, compact: true),
              style: TradeTypography.tag.copyWith(color: TradeColors.text),
            ),
          ],
        ),
      ],
    );
    final profit = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          historyUnit(r.realizedPnl, units?.margin, fixed: 2, signed: true),
          textAlign: TextAlign.end,
          style: TradeTypography.symbol.copyWith(
            fontSize: 14,
            height: 20 / 14,
            color: historyPnlColor(r.realizedPnl),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.tradingHistoryRealizedProfit,
          textAlign: TextAlign.end,
          style: TradeTypography.body.copyWith(color: TradeColors.positive),
        ),
      ],
    );
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth < 310 || MediaQuery.textScalerOf(context).scale(1) > 1.2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const SizedBox(height: 8), profit],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 8),
                      Expanded(child: profit),
                    ],
                  ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: TradeColors.line),
          ),
          HistoryRow(l.openOrdersOrderPrice, historyAmount(r.price, fixed: 6)),
          HistoryRow(l.tradingHistoryExecutedAmount, historyUnit(r.quantity, units?.base)),
          HistoryRow(
            l.tradingHistoryExecutedValue,
            historyUnit(r.notional, units?.quote, fixed: 2),
          ),
          HistoryRow(l.tradingHistoryRole, historyRole(l, r.maker)),
        ],
      ),
    );
  }
}

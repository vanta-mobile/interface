import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/aster_account.dart';
import '../domain/trading_history.dart';
import 'aster_open_order_card.dart';
import 'futures_history_labels.dart';
import 'trading_history_components.dart';
import 'trading_history_details.dart';

class TradingHistoryOrderCard extends StatefulWidget {
  const TradingHistoryOrderCard({super.key, required this.order, this.units});
  final HistoryOrder order;
  final AsterContractUnits? units;
  @override
  State<TradingHistoryOrderCard> createState() => _TradingHistoryOrderCardState();
}

class _TradingHistoryOrderCardState extends State<TradingHistoryOrderCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.order, l = AppLocalizations.of(context);
    final buy = r.side == 'BUY';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            key: Key('history-expand-${r.key}'),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow =
                      constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.2;
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.symbol, style: TradeTypography.symbol),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 7,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            historyDirection(
                              l,
                              r.side,
                              r.positionSide,
                              reduceOnly: r.closePosition == true || r.reduceOnly == true,
                            ),
                            style: TradeTypography.tag.copyWith(
                              color: buy ? TradeColors.positive : TradeColors.negative,
                            ),
                          ),
                          Text('|', style: TradeTypography.tag.copyWith(color: TradeColors.line)),
                          Text(
                            futuresHistoryOrderType(l, r.type),
                            style: TradeTypography.tag.copyWith(color: TradeColors.text),
                          ),
                          Text('|', style: TradeTypography.tag.copyWith(color: TradeColors.line)),
                          Text(
                            historyTime(r.time, compact: true).substring(0, 11),
                            style: TradeTypography.tag.copyWith(color: TradeColors.text),
                          ),
                        ],
                      ),
                    ],
                  );
                  final trailing = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: HistoryStatus(r.status)),
                      const SizedBox(width: 8),
                      HistoryExpand(expanded: expanded),
                    ],
                  );
                  return narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            title,
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerRight, child: trailing),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 8),
                            trailing,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
        if (expanded) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TradeColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HistoryRow(
                  l.tradingHistoryFilledPrice,
                  '${historyAmount(r.executed > Decimal.zero ? r.averagePrice : null, fixed: 6)} / ${r.price != null && r.price! > Decimal.zero
                      ? historyAmount(r.price, fixed: 6)
                      : r.type == 'MARKET' || r.type.endsWith('_MARKET')
                      ? l.openOrdersMarket
                      : historyPlaceholder}',
                ),
                HistoryRow(
                  l.tradingHistoryFilledValue(widget.units?.quote ?? historyPlaceholder),
                  '${historyAmount(r.filledValue, fixed: 2)} / ${historyAmount(r.orderValue, fixed: 2)}',
                ),
                if (r.type == 'TRAILING_STOP_MARKET') ...[
                  HistoryRow(
                    l.openOrdersActivationPrice,
                    historyAmount(r.activationPrice, fixed: 6),
                  ),
                  HistoryRow(
                    l.openOrdersCallbackRate,
                    r.callbackRate == null
                        ? historyPlaceholder
                        : '${historyAmount(r.callbackRate)}%',
                  ),
                ] else
                  HistoryRow(l.openOrdersTriggerPrice, historyTrigger(l, r)),
                HistoryRow(
                  l.openOrdersReduceOnly,
                  r.reduceOnly == null && r.closePosition != true
                      ? historyPlaceholder
                      : r.reduceOnly == true || r.closePosition == true
                      ? l.openOrdersYes
                      : l.openOrdersNo,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OpenOrderChipButton(label: l.openOrdersViewExplorer, onPressed: null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OpenOrderChipButton(
                        key: Key('history-details-${r.id}'),
                        label: l.tradingHistoryDetails,
                        onPressed: () => showTradingOrderDetails(context, r, widget.units),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
        const Divider(height: 1, thickness: 1, color: TradeColors.line),
      ],
    );
  }
}

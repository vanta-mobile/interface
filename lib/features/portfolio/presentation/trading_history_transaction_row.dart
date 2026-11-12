import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/trading_history.dart';
import 'futures_history_labels.dart';
import 'trading_history_components.dart';

class TradingHistoryTransactionRow extends StatelessWidget {
  const TradingHistoryTransactionRow({super.key, required this.transaction});
  final HistoryTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final r = transaction, l = AppLocalizations.of(context);
    final colored = {'REALIZED_PNL', 'FUNDING_FEE'}.contains(r.type);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historyUnit(r.amount, r.asset, signed: true),
                      style: TradeTypography.symbol.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                        color: colored ? historyPnlColor(r.amount) : TradeColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      historyTime(r.time),
                      style: TradeTypography.body.copyWith(color: TradeColors.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.symbol.isEmpty ? '-' : r.symbol,
                      textAlign: TextAlign.end,
                      style: TradeTypography.body.copyWith(fontSize: 14, height: 20 / 14),
                    ),
                    const SizedBox(height: 4),
                    HistoryTag(futuresIncomeLabel(l, r.type), outlined: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: TradeColors.line),
        ],
      ),
    );
  }
}

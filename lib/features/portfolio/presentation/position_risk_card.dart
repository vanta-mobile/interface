import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/position_risk.dart';
import 'position_adl_indicator.dart';
import 'position_valuation_rows.dart';
import 'account_event_status.dart';
import 'position_leverage_screen.dart';
import 'position_margin_mode_screen.dart';
import 'position_margin_screen.dart';
import 'live_order_screen.dart';

class PositionRiskCard extends StatelessWidget {
  const PositionRiskCard({super.key, required this.position});
  final PositionRisk position;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = position;
    final units = p.units;
    String amount(Decimal? value, String? unit) =>
        value == null ? '—' : '${marketNumber(value)} ${unit ?? l10n.accountUnitUnavailable}';
    final priceUnit = units == null ? null : '${units.quote}/${units.base}';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(p.symbol, style: Theme.of(context).textTheme.titleMedium),
          ValueRow(
            l10n.accountPositionDirection,
            p.balanceOnly
                ? l10n.positionRiskBalanceOnly
                : p.long
                ? l10n.long
                : l10n.short,
            color: p.balanceOnly
                ? AppColors.warning
                : p.long
                ? AppColors.positive
                : AppColors.negative,
          ),
          ValueRow(l10n.positionRiskSide, p.side),
          ValueRow(l10n.accountMarginMode, p.isolated ? l10n.accountIsolatedMode : l10n.cross),
          OutlinedButton(
            onPressed: () => openMarginModeSettings(context, p.symbol),
            child: Text(l10n.marginModeSettings),
          ),
          ValueRow(l10n.leverage, p.leverage == null ? '—' : '${p.leverage}×'),
          OutlinedButton(
            onPressed: () => openLeverageSettings(context, p.symbol),
            child: Text(l10n.leverageSettings),
          ),
          if (p.isolated && !p.balanceOnly)
            OutlinedButton(
              key: ValueKey('margin-adjust-${p.symbol}-${p.side}'),
              onPressed: () => openPositionMargin(context, symbol: p.symbol, side: p.side),
              child: Text(l10n.marginAdjustTitle),
            ),
          PositionAdlIndicator(position: p),
          ValueRow(l10n.quantity, amount(p.quantity, units?.base)),
          if (!p.balanceOnly)
            OutlinedButton.icon(
              key: ValueKey('live-close-${p.symbol}-${p.side}'),
              onPressed: () => openLiveClose(context, p.symbol, p.side),
              icon: const Icon(Icons.close_fullscreen),
              label: Text(l10n.liveCloseTitle),
            ),
          ValueRow(l10n.entry, p.balanceOnly ? '—' : amount(p.entryPrice, priceUnit)),
          if (!p.balanceOnly)
            OutlinedButton(
              key: ValueKey('live-tpsl-${p.symbol}-${p.side}'),
              onPressed: () => openPositionTriggers(context, p.symbol, p.side),
              child: Text(l10n.liveOrderPositionTriggers),
            ),
          PositionValuationRows(position: p),
          ValueRow(
            l10n.positionRiskLiquidation,
            p.balanceOnly || p.liquidationPrice == null || p.liquidationPrice! <= Decimal.zero
                ? '—'
                : amount(p.liquidationPrice, priceUnit),
          ),
          if (p.isolated) ...[
            ValueRow(l10n.positionRiskIsolatedWallet, amount(p.isolatedWallet, units?.margin)),
            ValueRow(l10n.positionRiskIsolatedMargin, amount(p.isolatedMargin, units?.margin)),
          ],
          if (p.updatedAt case final updated?)
            ValueRow(
              l10n.positionRiskUpdated,
              DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(updated.toUtc()),
            ),
          AccountEventRowTime(time: p.eventTime),
          if (p.eventTime != null)
            Text(l10n.positionEventFieldsHint, style: const TextStyle(color: AppColors.warning)),
          Text(l10n.positionRiskLiquidationHint, style: Theme.of(context).textTheme.bodySmall),
          if (p.balanceOnly)
            Text(l10n.positionRiskBalanceHint, style: const TextStyle(color: AppColors.warning)),
        ],
      ),
    );
  }
}

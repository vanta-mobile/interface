import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../portfolio/domain/futures_asset_mode.dart';
import '../../../portfolio/domain/live_order.dart';
import '../../../portfolio/domain/position_margin_mode.dart';
import '../../../portfolio/presentation/futures_asset_mode_screen.dart';
import '../../../portfolio/presentation/position_leverage_screen.dart';
import '../../../portfolio/presentation/position_margin_mode_screen.dart';
import '../trade_theme.dart';

class TradeAccountSettings extends StatelessWidget {
  const TradeAccountSettings({
    super.key,
    required this.symbol,
    required this.data,
    required this.enabled,
  });
  final String symbol;
  final LiveOrderContext? data;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), funds = data?.funds;
    return Row(
      children: [
        for (final entry in [
          (
            l.accountMarginMode,
            data == null
                ? '—'
                : data!.marginMode == PositionMarginMode.cross
                ? l.cross
                : l.accountIsolatedMode,
            () => openMarginModeSettings(context, symbol),
          ),
          (
            l.leverageSettings,
            data == null ? '—' : '${data!.leverage}×',
            () => openLeverageSettings(context, symbol),
          ),
          (
            l.assetModeSettings,
            funds == null
                ? '—'
                : funds.assetMode == FuturesAssetMode.multi
                ? l.assetModeMulti
                : l.assetModeSingle,
            () => openAssetModeSettings(context),
          ),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${entry.$1}: ${entry.$2}',
                child: TextButton(
                  onPressed: enabled ? entry.$3 : null,
                  style: TextButton.styleFrom(
                    backgroundColor: TradeColors.card,
                    minimumSize: const Size(44, 27),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    entry.$2,
                    style: TradeTypography.caption.copyWith(color: TradeColors.text),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

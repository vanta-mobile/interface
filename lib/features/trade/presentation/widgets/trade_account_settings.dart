import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../market/application/public_leverage_provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../portfolio/application/main_order_refresh_provider.dart';
import '../../../portfolio/domain/futures_asset_mode.dart';
import '../../../portfolio/domain/live_order.dart';
import '../../../portfolio/domain/position_margin_mode.dart';
import '../../../portfolio/presentation/futures_asset_mode_sheet.dart';
import '../../../portfolio/presentation/position_leverage_sheet.dart';
import '../../../portfolio/presentation/position_margin_mode_sheet.dart';
import '../trade_theme.dart';

/// Button text and full name; most settings show the same text in both.
(String, String) _same(String value) => (value, value);

class TradeAccountSettings extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), funds = data?.funds;
    final publicLeverage = data == null
        ? (ref.watch(publicLeverageProvider).value ?? const {})[symbol]?.defaultLeverage()
        : null;
    return Row(
      children: [
        for (final entry in [
          (
            l.accountMarginMode,
            _same(
              data == null
                  ? l.cross
                  : data!.marginMode == PositionMarginMode.cross
                  ? l.cross
                  : l.accountIsolatedMode,
            ),
            () => openMarginModeSettings(context, symbol),
          ),
          (
            l.leverageSettings,
            _same(
              data != null
                  ? '${data!.leverage}×'
                  : publicLeverage == null
                  ? '—'
                  : '$publicLeverage×',
            ),
            () => openLeverageSettings(context, symbol),
          ),
          (
            l.assetModeSettings,
            // Guests see the PRD first-visit preset: single-asset mode. The
            // button shows the design's S/M; the tooltip keeps the full name.
            switch (funds?.assetMode ?? (data == null ? FuturesAssetMode.single : null)) {
              FuturesAssetMode.multi => (l.assetModeMultiShort, l.assetModeMulti),
              FuturesAssetMode.single => (l.assetModeSingleShort, l.assetModeSingle),
              null => ('—', '—'),
            },
            () => openAssetModeSettings(context),
          ),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${entry.$1}: ${entry.$2.$2}',
                child: TextButton(
                  onPressed: enabled
                      ? () {
                          ref.read(mainOrderRefreshProvider.notifier).stopBackground();
                          entry.$3();
                        }
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: TradeColors.card,
                    minimumSize: const Size(44, 27),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    entry.$2.$1,
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

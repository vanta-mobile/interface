import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/position_margin_mode.dart';

/// Show read account settings; new-user presets never stand in for a snapshot.
class QuickOrderAccountSettings extends StatelessWidget {
  const QuickOrderAccountSettings({super.key, required this.data});
  final LiveOrderContext? data;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), funds = data?.funds;
    final balance = funds?.account.availableBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          l10n.leverageCurrentSetting,
          data == null ? '—' : '${data!.leverage}×',
          key: const Key('quick-order-leverage'),
        ),
        ValueRow(
          l10n.accountMarginMode,
          data == null
              ? '—'
              : data!.marginMode == PositionMarginMode.cross
              ? l10n.cross
              : l10n.accountIsolatedMode,
          key: const Key('quick-order-margin-mode'),
        ),
        ValueRow(
          l10n.positionModeSettings,
          data == null
              ? '—'
              : data!.mode == FuturesPositionMode.oneWay
              ? l10n.positionModeOneWay
              : l10n.positionModeHedge,
          key: const Key('quick-order-position-mode'),
        ),
        ValueRow(
          l10n.assetModeCurrentSetting,
          funds == null
              ? '—'
              : funds.assetMode == FuturesAssetMode.multi
              ? l10n.assetModeMulti
              : l10n.assetModeSingle,
          key: const Key('quick-order-asset-mode'),
        ),
        ValueRow(
          l10n.liveOrderAvailableUsdt,
          balance == null ? '—' : '$balance USDT',
          key: const Key('quick-order-available'),
        ),
      ],
    );
  }
}

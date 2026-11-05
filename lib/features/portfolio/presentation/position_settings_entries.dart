import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'futures_position_mode_screen.dart';
import 'futures_asset_mode_screen.dart';
import 'position_leverage_screen.dart';
import 'position_margin_mode_screen.dart';

class PositionSettingsEntries extends StatelessWidget {
  const PositionSettingsEntries({super.key, required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('open-asset-mode-settings'),
          onPressed: () => openAssetModeSettings(context),
          icon: const Icon(Icons.account_balance_outlined),
          label: Text(l10n.assetModeSettings),
        ),
        OutlinedButton.icon(
          key: const Key('open-position-mode-settings'),
          onPressed: () => openPositionModeSettings(context),
          icon: const Icon(Icons.swap_horiz),
          label: Text(l10n.positionModeSettings),
        ),
        OutlinedButton.icon(
          key: const Key('open-margin-mode-settings'),
          onPressed: () => openMarginModeSettings(context, symbol),
          icon: const Icon(Icons.shield_outlined),
          label: Text(l10n.marginModeSettings),
        ),
        OutlinedButton.icon(
          key: const Key('open-leverage-settings'),
          onPressed: () => openLeverageSettings(context, symbol),
          icon: const Icon(Icons.tune),
          label: Text(l10n.leverageSettings),
        ),
      ],
    );
  }
}

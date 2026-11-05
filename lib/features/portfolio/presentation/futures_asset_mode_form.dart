import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_asset_mode.dart';
import 'futures_asset_mode_status.dart';

class FuturesAssetModeForm extends StatelessWidget {
  const FuturesAssetModeForm({
    super.key,
    required this.settings,
    required this.stale,
    required this.busy,
    required this.target,
    required this.onChanged,
    required this.onReview,
  });
  final FuturesAssetModeContext settings;
  final bool stale, busy;
  final FuturesAssetMode? target;
  final ValueChanged<FuturesAssetMode?> onChanged;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ValueRow(l10n.assetModeCurrentSetting, assetModeLabel(l10n, settings.current)),
        Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(settings.receivedAt.toUtc())} UTC'),
        if (stale)
          Text(l10n.assetModeContextExpired, style: const TextStyle(color: AppColors.warning)),
        if (settings.isolatedSymbols.isNotEmpty) ...[
          Text(l10n.assetModeIsolatedBlocker, style: const TextStyle(color: AppColors.warning)),
          for (final symbol in settings.isolatedSymbols) SelectableText(symbol),
        ],
        if (settings.current == FuturesAssetMode.multi && settings.blocks(FuturesAssetMode.single))
          Text(
            settings.usdtWalletBalance == null ? l10n.rebalanceUnknownUsdt : l10n.rebalanceRequired,
            style: const TextStyle(color: AppColors.warning),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FuturesAssetMode>(
          key: const Key('asset-mode-target'),
          initialValue: target,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.assetModeTarget),
          items: [
            for (final mode in FuturesAssetMode.values)
              DropdownMenuItem(value: mode, child: Text(assetModeLabel(l10n, mode))),
          ],
          onChanged: busy ? null : onChanged,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('asset-mode-review'),
          onPressed: onReview,
          child: Text(l10n.assetModeReviewChange),
        ),
      ],
    );
  }
}

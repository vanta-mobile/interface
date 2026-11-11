import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../portfolio/application/futures_asset_mode_provider.dart';
import '../../../portfolio/application/futures_position_mode_provider.dart';
import '../../../portfolio/application/live_order_provider.dart';
import '../../../portfolio/domain/futures_asset_mode.dart';
import '../../../portfolio/domain/futures_position_mode.dart';
import '../../../portfolio/presentation/futures_asset_mode_screen.dart';
import '../../../portfolio/presentation/futures_position_mode_screen.dart';
import '../../../portfolio/presentation/mode_settings_sheet.dart';
import '../../../portfolio/presentation/portfolio_components.dart';
import '../trade_theme.dart';

Future<void> openTradeModeSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const TradeModeSettings());

class TradeModeSettings extends ConsumerWidget {
  const TradeModeSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final asset = ref.watch(futuresAssetModeProvider);
    final position = ref.watch(futuresPositionModeProvider);
    final live = ref.watch(liveOrderProvider).context;
    final ownAsset = asset.result?.observed ?? asset.context?.current;
    final assetTime = asset.result?.checkedAt ?? asset.context?.receivedAt;
    final assetMode =
        live?.funds != null && (assetTime == null || live!.receivedAt.isAfter(assetTime))
        ? live!.funds!.assetMode
        : ownAsset ?? live?.funds?.assetMode;
    final ownPosition = position.result?.observed ?? position.context?.current;
    final positionTime = position.result?.checkedAt ?? position.context?.receivedAt;
    final positionMode =
        live != null && (positionTime == null || live.receivedAt.isAfter(positionTime))
        ? live.mode
        : ownPosition ?? live?.mode;
    return ModeSheetBody(
      key: const Key('trade-mode-settings'),
      title: l.modeAccountSettings,
      onRefresh: () async {
        final identity = ref.read(authProvider).identity;
        final assetController = ref.read(futuresAssetModeProvider.notifier);
        final positionController = ref.read(futuresPositionModeProvider.notifier);
        await (ref.read(futuresAssetModeProvider).needsRecheck
            ? assetController.recheck()
            : assetController.load());
        if (!context.mounted || ref.read(authProvider).identity != identity) return;
        await (ref.read(futuresPositionModeProvider).needsRecheck
            ? positionController.recheck()
            : positionController.load());
      },
      children: [
        _ModeRow(
          key: const Key('settings-asset-mode'),
          label: l.modeAssetTitle,
          value: assetMode == null
              ? '—'
              : assetMode == FuturesAssetMode.single
              ? l.modeSingleShort
              : l.modeMultiShort,
          onTap: () => openAssetModeSettings(context),
        ),
        _ModeRow(
          key: const Key('settings-position-mode'),
          label: l.modePositionTitle,
          value: positionMode == null
              ? '—'
              : positionMode == FuturesPositionMode.oneWay
              ? l.positionModeOneWay
              : l.positionModeHedge,
          onTap: () => openPositionModeSettings(context),
        ),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({super.key, required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TradeTypography.option.copyWith(color: TradeColors.muted)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value, textAlign: TextAlign.end, style: TradeTypography.symbol),
            ),
            const SizedBox(width: 4),
            const SizedBox.square(
              dimension: 16,
              child: Center(
                child: PortfolioIcon('chevron-right.svg', size: 12, color: TradeColors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

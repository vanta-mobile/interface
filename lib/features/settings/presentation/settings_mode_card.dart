import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/futures_asset_mode_provider.dart';
import '../../portfolio/application/futures_position_mode_provider.dart';
import '../../portfolio/application/live_order_provider.dart';
import '../../portfolio/domain/futures_asset_mode.dart';
import '../../portfolio/domain/futures_position_mode.dart';
import '../../portfolio/presentation/futures_asset_mode_screen.dart';
import '../../portfolio/presentation/futures_position_mode_screen.dart';
import 'settings_components.dart';

/// Reloads both account modes for the same identity; awaited by pull-to-refresh.
Future<void> refreshAccountModes(WidgetRef ref, BuildContext context) async {
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
}

/// Asset and position mode rows; the newest of the mode reads and the live
/// order context wins so a stale mode read never overrides a newer snapshot.
class SettingsModeCard extends ConsumerWidget {
  const SettingsModeCard({super.key});
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
    return SettingsCard(
      children: [
        SettingsRow(
          key: const Key('settings-asset-mode'),
          label: l.modeAssetTitle,
          value: assetMode == null
              ? '—'
              : assetMode == FuturesAssetMode.single
              ? l.modeSingleShort
              : l.modeMultiShort,
          trailing: const SettingsIcon('chevron-right'),
          onTap: () => openAssetModeSettings(context),
        ),
        SettingsRow(
          key: const Key('settings-position-mode'),
          label: l.modePositionTitle,
          value: positionMode == null
              ? '—'
              : positionMode == FuturesPositionMode.oneWay
              ? l.positionModeOneWay
              : l.positionModeHedge,
          trailing: const SettingsIcon('chevron-right'),
          onTap: () => openPositionModeSettings(context),
        ),
      ],
    );
  }
}

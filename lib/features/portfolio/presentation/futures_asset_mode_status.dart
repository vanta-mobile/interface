import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_asset_mode_provider.dart';
import '../domain/futures_asset_mode.dart';

String assetModeLabel(AppLocalizations l10n, FuturesAssetMode mode) =>
    mode == FuturesAssetMode.single ? l10n.assetModeSingle : l10n.assetModeMulti;

class FuturesAssetModeStatus extends ConsumerWidget {
  const FuturesAssetModeStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(futuresAssetModeProvider), l10n = AppLocalizations.of(context);
    final result = state.result, intent = state.intent;
    final failure = state.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(switch (state.step) {
            AssetModeStep.signingContext || AssetModeStep.signing => l10n.accountReadSigning,
            AssetModeStep.loadingContext => l10n.accountReadLoading,
            AssetModeStep.submitting => l10n.assetModeSubmitting,
            AssetModeStep.checkSigning => l10n.assetModeCheckSigning,
            AssetModeStep.checking => l10n.assetModeChecking,
            _ => l10n.accountReadPreparing,
          }, key: const Key('asset-mode-progress')),
        ],
        if (intent != null) ...[
          Text(l10n.assetModeAllSymbols),
          SelectableText(intent.context.address),
        ],
        if (result != null && intent != null) ...[
          Text(
            result.needsRecheck
                ? l10n.assetModeOutcomeUnknown
                : result.observed == intent.target
                ? l10n.assetModeVerified(assetModeLabel(l10n, result.observed!))
                : l10n.assetModeObservedDifferent(
                    assetModeLabel(l10n, result.observed!),
                    assetModeLabel(l10n, intent.target),
                  ),
            key: const Key('asset-mode-result'),
          ),
          if (result.checkedAt case final time?)
            Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time.toUtc())} UTC'),
          Text(l10n.leverageResultScope, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (failure != null)
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : '\n${l10n.accountErrorCode(failure.code!)}'}',
            style: const TextStyle(color: AppColors.negative),
            key: const Key('asset-mode-error'),
          ),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('asset-mode-recheck'),
            onPressed: state.busy || ref.watch(authProvider.select((s) => s.busy))
                ? null
                : () => ref.read(futuresAssetModeProvider.notifier).recheck(),
            child: Text(l10n.leverageRecheck),
          ),
      ],
    );
  }
}

import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/asset_yield_provider.dart';
import '../domain/asset_yield.dart';

class AssetYieldBadge extends ConsumerWidget {
  const AssetYieldBadge({super.key, required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = YieldAsset.forSymbol(symbol);
    if (asset == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(assetYieldProvider(asset)), quote = state.quote;
    final rate = quote?.percent.toStringAsFixed(2) ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            key: Key('asset-yield-details-$symbol'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              asset == YieldAsset.usdf ? l10n.assetYieldUsdf(rate) : l10n.assetYieldAsbnb(rate),
              key: Key('asset-yield-rate-$symbol'),
              style: TextStyle(color: state.stale ? AppColors.warning : AppColors.secondary),
            ),
            children: [
              _YieldDetails(asset: asset, quote: quote),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('asset-yield-refresh-$symbol'),
                  onPressed: state.loading || !state.active
                      ? null
                      : ref.read(assetYieldProvider(asset).notifier).refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.assetYieldRefresh),
                ),
              ),
            ],
          ),
        ),
        if (state.stale)
          Text(l10n.assetYieldStale, style: const TextStyle(color: AppColors.warning)),
        if (!state.active) Text(l10n.assetYieldPaused),
        if (state.failureKey case final key?)
          Text(
            apiErrorText(
              context,
              key,
              state.errorDetails,
              fallbackText: switch (key) {
                'accountDataInvalid' => l10n.assetYieldInvalid,
                'accountNetwork' => l10n.assetYieldNetwork,
                'accountRateLimited' => l10n.accountRateLimited,
                _ => l10n.assetYieldFailed,
              },
            ),
            style: const TextStyle(color: AppColors.warning),
          ),
        if (state.loading) ...[const LinearProgressIndicator(), Text(l10n.assetYieldLoading)],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _YieldDetails extends StatelessWidget {
  const _YieldDetails({required this.asset, required this.quote});
  final YieldAsset asset;
  final AssetYieldQuote? quote;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), value = quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          asset == YieldAsset.usdf ? l10n.assetYieldUsdfScope : l10n.assetYieldAsbnbScope,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (value != null) ...[
          Text(l10n.assetYieldSourceDate(value.sourceDay.toIso8601String().substring(0, 10))),
          if (value.basePercent != null && value.tradePercent != null)
            Text(
              l10n.assetYieldParts(
                value.basePercent!.toStringAsFixed(2),
                value.tradePercent!.toStringAsFixed(2),
              ),
            ),
          if (value.updatedAt != null)
            Text(l10n.assetYieldUpdated(value.updatedAt!.toIso8601String())),
          Text(l10n.assetYieldReadTime(value.receivedAt.toIso8601String())),
        ],
      ],
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/asset_index_provider.dart';
import '../domain/asset_valuation.dart';

String _usd(Decimal? value) => value == null ? '—' : '${marketNumber(value)} USD';
String _btc(Decimal? value) => value == null ? '—' : '≈ ${marketNumber(value)} BTC';

class AssetAmountValuation extends ConsumerWidget {
  const AssetAmountValuation({
    super.key,
    required this.asset,
    required this.quantity,
    required this.label,
    this.accountStale = false,
  });
  final String asset, label;
  final Decimal? quantity;
  final bool accountStale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), prices = ref.watch(assetIndexProvider);
    final value = quantity == null ? null : AssetAmountValue(quantity!, asset, prices);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.assetValueUsd(label), _usd(value?.usd)),
        ValueRow(l10n.assetValueBtc(label), _btc(value?.btc)),
        if (value == null || value.usd == null || value.btc == null)
          Text(l10n.assetValueUnavailable, style: Theme.of(context).textTheme.bodySmall)
        else if (accountStale || !value.fresh || !value.btcFresh)
          Text(l10n.assetValueStale, style: const TextStyle(color: AppColors.warning)),
      ],
    );
  }
}

class AssetWalletSummary extends ConsumerWidget {
  const AssetWalletSummary({
    super.key,
    required this.quantities,
    required this.label,
    this.accountStale = false,
  });
  final Map<String, Decimal> quantities;
  final String label;
  final bool accountStale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), prices = ref.watch(assetIndexProvider);
    final value = AssetWalletValue(
      quantities.entries.map((e) => AssetAmountValue(e.value, e.key, prices)),
      prices,
    );
    final partial = value.missing > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        ValueRow(
          partial ? l10n.assetValueKnownSubtotal : l10n.assetValueWalletTotal,
          _usd(partial && value.known == 0 ? null : value.usd),
        ),
        ValueRow(l10n.assetValueBtcEstimate, _btc(partial && value.known == 0 ? null : value.btc)),
        if (partial) Text(l10n.assetValueMissing(value.missing)),
        if (accountStale || value.stale > 0 || !value.btcFresh)
          Text(l10n.assetValueStale, style: const TextStyle(color: AppColors.warning)),
        const AssetIndexStatus(),
      ],
    );
  }
}

class AssetIndexStatus extends ConsumerWidget {
  const AssetIndexStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), prices = ref.watch(assetIndexProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.assetValueScope, style: Theme.of(context).textTheme.bodySmall),
        if (prices.snapshot case final snapshot?)
          Text(l10n.assetIndexReadTime(snapshot.receivedAt.toIso8601String())),
        if (prices.loading) ...[const LinearProgressIndicator(), Text(l10n.assetIndexLoading)],
        if (!prices.active) Text(l10n.assetIndexPaused),
        if (prices.failed) Text(l10n.assetIndexFailed),
        OutlinedButton.icon(
          key: const Key('asset-index-refresh'),
          onPressed: prices.loading || !prices.active
              ? null
              : ref.read(assetIndexProvider.notifier).refresh,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.assetIndexRefresh),
        ),
      ],
    );
  }
}

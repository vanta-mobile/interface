import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/aster_spot_account.dart';
import '../application/asset_index_provider.dart';
import '../domain/asset_valuation.dart';
import 'asset_valuation_rows.dart';
import 'asset_yield_badge.dart';
import 'asset_identity.dart';
import '../application/asset_metadata_provider.dart';
import '../domain/asset_metadata.dart';
import '../../../core/presentation/status_view.dart';

class SpotBalanceRows extends ConsumerStatefulWidget {
  const SpotBalanceRows({super.key, required this.account, this.accountStale = false});
  final AsterSpotAccount account;
  final bool accountStale;
  @override
  ConsumerState<SpotBalanceRows> createState() => _SpotBalanceRowsState();
}

class _SpotBalanceRowsState extends ConsumerState<SpotBalanceRows> {
  String query = '';
  bool hideZero = true;
  bool hideLow = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prices = ref.watch(assetIndexProvider);
    final metadata = ref.watch(assetMetadataProvider(AssetMetadataSource.names)).snapshot;
    final balances = widget.account.balances.where(
      (balance) =>
          (!hideZero || balance.total != Decimal.zero) &&
          (!hideLow ||
              widget.accountStale ||
              AssetAmountValue(balance.total, balance.asset, prices).aboveLowBalanceThreshold !=
                  false) &&
          (balance.asset.toLowerCase().contains(query) ||
              metadata?.forSymbol(balance.asset)?.matches(query) == true),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.spotAssetBalances, style: Theme.of(context).textTheme.titleLarge),
        AssetWalletSummary(
          label: l10n.assetValueSpotScope,
          accountStale: widget.accountStale,
          quantities: {for (final b in widget.account.balances) b.asset: b.total},
        ),
        const AssetMetadataStatus(),
        const SizedBox(height: 12),
        TextField(
          key: const Key('spot-asset-search'),
          decoration: InputDecoration(
            labelText: l10n.accountSearchAsset,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
        ),
        CheckboxListTile(
          key: const Key('spot-hide-zero-balance'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.accountHideZero),
          value: hideZero,
          onChanged: (value) => setState(() => hideZero = value ?? true),
        ),
        CheckboxListTile(
          key: const Key('spot-hide-low-balance'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.assetValueHideLow),
          subtitle: Text(l10n.assetValueHideLowScope),
          value: hideLow,
          onChanged: (value) => setState(() => hideLow = value ?? false),
        ),
        if (balances.isEmpty)
          StatusEmptyView(
            key: const Key('spot-assets-empty'),
            title: widget.account.balances.isEmpty
                ? l10n.statusNoAssetsTitle
                : l10n.statusNoResultsTitle,
            message: widget.account.balances.isEmpty
                ? l10n.spotNoAssets
                : l10n.accountNoMatchingAssets,
          ),
        for (final balance in balances)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SpotBalanceCard(balance: balance, stale: widget.accountStale),
          ),
      ],
    );
  }
}

class _SpotBalanceCard extends StatelessWidget {
  const _SpotBalanceCard({required this.balance, required this.stale});
  final AsterSpotBalance balance;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String amount(Decimal value) => '${marketNumber(value)} ${balance.asset}';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssetIdentity(symbol: balance.asset),
          AssetYieldBadge(symbol: balance.asset),
          ValueRow(l10n.spotTotalBalance, amount(balance.total)),
          AssetAmountValuation(
            asset: balance.asset,
            quantity: balance.total,
            label: l10n.spotTotalBalance,
            accountStale: stale,
          ),
          ValueRow(tr(context, 'available'), amount(balance.free)),
          AssetAmountValuation(
            asset: balance.asset,
            quantity: balance.free,
            label: tr(context, 'available'),
            accountStale: stale,
          ),
          ValueRow(l10n.spotLockedBalance, amount(balance.locked)),
        ],
      ),
    );
  }
}

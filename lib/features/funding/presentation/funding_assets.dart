import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/funding_catalog.dart';
import '../domain/funding_fee.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_wallet_screen.dart';
import 'funding_fee_screen.dart';
import 'withdraw_info_panel.dart';
import 'withdrawal_screen.dart';

class FundingAssets extends StatefulWidget {
  const FundingAssets({super.key, required this.catalog, required this.chainId});
  final FundingCatalog catalog;
  final int chainId;
  @override
  State<FundingAssets> createState() => _FundingAssetsState();
}

class _FundingAssetsState extends State<FundingAssets> with AutomaticKeepAliveClientMixin {
  final search = TextEditingController();
  String query = '';
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final networkAssets = widget.catalog.assets.where((a) => a.chainId == widget.chainId);
    final assets = networkAssets.where(
      (a) => a.asset.toLowerCase().contains(query) || a.displayName.toLowerCase().contains(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('funding-asset-search'),
          controller: search,
          decoration: InputDecoration(
            labelText: l10n.fundingAssetSearch,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        if (assets.isEmpty)
          Text(networkAssets.isEmpty ? l10n.fundingNoNetworkAssets : l10n.fundingNoMatches),
        for (final asset in assets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    asset.displayName == asset.asset
                        ? asset.asset
                        : '${asset.displayName} (${asset.asset})',
                    key: Key('funding-asset-${asset.chainId}-${asset.asset}'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(asset.isNative ? l10n.fundingNativeAsset : l10n.fundingTokenAsset),
                  if (!asset.isNative) ...[
                    Text(l10n.fundingTokenContract),
                    SelectableText(asset.tokenAddress),
                  ],
                  if (widget.catalog.query.operation == FundingOperation.deposit)
                    DepositWalletEntry(
                      query: DepositWalletQuery(market: widget.catalog.query.market, asset: asset),
                    ),
                  if (widget.catalog.query.operation == FundingOperation.withdraw) ...[
                    WithdrawAssetLimits(asset: asset, market: widget.catalog.query.market),
                    OutlinedButton(
                      key: Key('withdrawal-entry-${asset.chainId}-${asset.asset}'),
                      onPressed: () => openWithdrawal(
                        context,
                        DepositWalletQuery(market: widget.catalog.query.market, asset: asset),
                      ),
                      child: Text(l10n.withdrawalSubmit),
                    ),
                    FundingFeeEntry(
                      query: FundingFeeQuery(
                        market: widget.catalog.query.market,
                        chainId: asset.chainId,
                        asset: asset.asset,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

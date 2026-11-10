import '../domain/isolated_margin_ratio.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/aster_account.dart';
import 'account_event_status.dart';
import 'asset_valuation_rows.dart';
import 'asset_collateral_rows.dart';
import 'asset_yield_badge.dart';
import 'asset_identity.dart';
import '../application/asset_metadata_provider.dart';
import '../domain/asset_metadata.dart';
import '../../../core/presentation/status_view.dart';
import '../../funding/domain/funding_catalog.dart';
import '../../funding/presentation/funding_screen.dart';

class AsterAccountRows extends ConsumerStatefulWidget {
  const AsterAccountRows({super.key, required this.account, this.accountStale = false});
  final AsterAccount account;
  final bool accountStale;
  @override
  ConsumerState<AsterAccountRows> createState() => _AsterAccountRowsState();
}

class _AsterAccountRowsState extends ConsumerState<AsterAccountRows> {
  bool hideZero = true;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metadata = ref.watch(assetMetadataProvider(AssetMetadataSource.names)).snapshot;
    final assets = widget.account.assets
        .where(
          (a) =>
              (a.asset.toLowerCase().contains(query) ||
                  metadata?.forSymbol(a.asset)?.matches(query) == true) &&
              (!hideZero ||
                  {'USDF', 'ASBNB'}.contains(a.asset) ||
                  a.walletBalance != Decimal.zero ||
                  (a.unrealizedProfit ?? Decimal.zero) != Decimal.zero ||
                  (a.crossWalletBalance ?? Decimal.zero) != Decimal.zero ||
                  (a.crossUnrealizedProfit ?? Decimal.zero) != Decimal.zero ||
                  (a.availableBalance ?? Decimal.zero) != Decimal.zero),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.accountAssetBalances, style: Theme.of(context).textTheme.titleLarge),
        AssetWalletSummary(
          label: l10n.assetValuePerpScope,
          accountStale: widget.accountStale,
          quantities: {for (final a in widget.account.assets) a.asset: a.walletBalance},
        ),
        const AssetMetadataStatus(),
        const SizedBox(height: 12),
        TextField(
          key: const Key('account-asset-search'),
          decoration: InputDecoration(
            labelText: l10n.accountSearchAsset,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.accountHideZero),
          value: hideZero,
          onChanged: (value) => setState(() => hideZero = value ?? true),
        ),
        if (assets.isEmpty)
          widget.account.assets.isEmpty
              ? StatusEmptyView(
                  key: const Key('account-assets-empty'),
                  title: l10n.statusNoAssetsTitle,
                  message: l10n.statusNoAssetsMessage,
                  actionLabel: l10n.fundingDeposit,
                  onAction: () => openFunding(context, FundingOperation.deposit),
                )
              : StatusEmptyView(
                  key: const Key('account-assets-empty'),
                  title: l10n.statusNoResultsTitle,
                  message: l10n.accountNoMatchingAssets,
                ),
        for (final asset in assets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AssetCard(
              address: widget.account.address,
              asset: asset,
              stale: widget.accountStale,
              receivedAt: widget.account.receivedAt,
              hasAccountEvents: widget.account.lastEventAt != null,
              positions: widget.account.positions,
            ),
          ),
        const SizedBox(height: 20),
        Text(l10n.accountLivePositions, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (widget.account.positions.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(l10n.accountNoPositions)),
        for (final position in widget.account.positions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PositionCard(position: position),
          ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.address,
    required this.asset,
    required this.stale,
    required this.receivedAt,
    required this.hasAccountEvents,
    required this.positions,
  });
  final AsterAssetBalance asset;
  final String address;
  final bool stale, hasAccountEvents;
  final DateTime receivedAt;
  final List<AsterPosition> positions;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String amount(Decimal? value) => value == null ? '—' : '${marketNumber(value)} ${asset.asset}';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssetIdentity(symbol: asset.asset),
          AssetYieldBadge(symbol: asset.asset),
          ValueRow(l10n.accountWalletBalance, amount(asset.walletBalance)),
          AssetAmountValuation(
            asset: asset.asset,
            quantity: asset.walletBalance,
            label: l10n.accountWalletBalance,
            accountStale: stale,
          ),
          ValueRow(
            l10n.asterMarginBalance,
            amount(
              asset.unrealizedProfit == null ? null : asset.walletBalance + asset.unrealizedProfit!,
            ),
          ),
          AssetAmountValuation(
            asset: asset.asset,
            quantity: asset.unrealizedProfit == null
                ? null
                : asset.walletBalance + asset.unrealizedProfit!,
            label: l10n.asterMarginBalance,
            accountStale: stale,
          ),
          if (asset.crossWalletBalance != null)
            ValueRow(l10n.accountCrossWalletBalance, amount(asset.crossWalletBalance)),
          ValueRow(tr(context, 'available'), amount(asset.availableBalance)),
          ValueRow(l10n.accountUnrealizedPnl, amount(asset.unrealizedProfit)),
          AssetCollateralRows(
            accountAddress: address,
            asset: asset,
            accountReceivedAt: receivedAt,
            accountStale: stale,
            hasAccountEvents: hasAccountEvents,
            positions: positions,
          ),
          AccountEventRowTime(time: asset.eventTime),
          if (asset.marginAvailable != null)
            Text(
              asset.marginAvailable!
                  ? l10n.accountCollateralEligible
                  : l10n.accountCollateralIneligible,
              style: TextStyle(
                color: asset.marginAvailable! ? AppColors.secondary : AppColors.warning,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position});
  final AsterPosition position;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final units = position.units;
    final ratio = isolatedMarginRatio(position);
    String amount(Decimal? value, String? unit) =>
        value == null ? '—' : '${marketNumber(value)} ${unit ?? l10n.accountUnitUnavailable}';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(position.symbol, style: Theme.of(context).textTheme.titleMedium),
          ValueRow(
            l10n.accountPositionDirection,
            position.quantity == Decimal.zero
                ? l10n.positionRiskBalanceOnly
                : tr(context, position.long ? 'long' : 'short'),
            color: position.quantity == Decimal.zero
                ? AppColors.warning
                : position.long
                ? AppColors.positive
                : AppColors.negative,
          ),
          ValueRow(tr(context, 'quantity'), amount(position.quantity.abs(), units?.base)),
          ValueRow(
            tr(context, 'entry'),
            amount(position.entryPrice, units == null ? null : '${units.quote}/${units.base}'),
          ),
          ValueRow(l10n.accountUnrealizedPnl, amount(position.unrealizedProfit, units?.margin)),
          ValueRow(l10n.accountPositionMargin, amount(position.initialMargin, units?.margin)),
          if (position.isolated == true && position.isolatedWallet != null)
            ValueRow(
              l10n.positionRiskIsolatedWallet,
              amount(position.isolatedWallet, units?.margin),
            ),
          if (position.isolated == true) ...[
            ValueRow(
              l10n.marginAdjustRatio,
              ratio.percent == null ? '—' : '${ratio.percent!.toStringAsFixed(2)}%',
            ),
            if (ratio.atRisk)
              Text(l10n.marginAdjustEquityRisk, style: const TextStyle(color: AppColors.warning)),
            Text(l10n.marginAdjustRatioHint, style: Theme.of(context).textTheme.bodySmall),
          ],
          AccountEventRowTime(time: position.eventTime),
          if (position.leverage != null) ValueRow(tr(context, 'leverage'), '${position.leverage}×'),
          if (position.isolated != null)
            ValueRow(
              l10n.accountMarginMode,
              position.isolated! ? l10n.accountIsolatedMode : l10n.cross,
            ),
        ],
      ),
    );
  }
}

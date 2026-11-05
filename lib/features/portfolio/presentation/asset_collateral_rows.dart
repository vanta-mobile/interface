import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../market/domain/mark_prices.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/asset_index_provider.dart';
import '../application/collateral_mark_prices_provider.dart';
import '../domain/aster_account.dart';
import '../domain/asset_collateral.dart';

class AssetCollateralRows extends ConsumerWidget {
  const AssetCollateralRows({
    super.key,
    required this.accountAddress,
    required this.asset,
    required this.accountReceivedAt,
    this.accountStale = false,
    this.hasAccountEvents = false,
    this.positions = const [],
  });
  final String accountAddress;
  final AsterAssetBalance asset;
  final List<AsterPosition> positions;
  final DateTime accountReceivedAt;
  final bool accountStale, hasAccountEvents;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final relevant = collateralPositions(positions, asset.asset);
    final canUseMarks =
        asset.marginAvailable == true &&
        !hasAccountEvents &&
        asset.eventTime == null &&
        relevant.isNotEmpty &&
        relevant.every(supportsCollateralMarkPnl);
    final marks = canUseMarks
        ? ref
                  .watch(
                    collateralMarkPricesProvider(collateralMarkScope(accountAddress, positions)),
                  )
                  .value ??
              MarkPrices()
        : MarkPrices();
    final value = AssetCollateralValue(
      asset: asset,
      prices: ref.watch(assetIndexProvider),
      accountReceivedAt: accountReceivedAt,
      accountStale: accountStale,
      hasAccountEvents: hasAccountEvents,
      liveCrossPnl: AssetCrossPnl(relevant, marks),
    );
    final issue = switch (value.issue) {
      AssetCollateralIssue.eligibilityUnknown => l10n.collateralEligibilityUnknown,
      AssetCollateralIssue.ineligible => l10n.accountCollateralIneligible,
      AssetCollateralIssue.equityUnknown => l10n.collateralEquityUnknown,
      AssetCollateralIssue.events => l10n.collateralEventsNeedRead,
      AssetCollateralIssue.ratesUnknown => l10n.collateralRatesUnknown,
      null => null,
    };
    return Column(
      key: ValueKey('asset-collateral-${asset.asset}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.collateralContribution, _amount(value.usd, 'USD')),
        if (value.usd != null)
          Text(
            value.livePnl ? l10n.collateralLiveMarks : l10n.collateralSnapshotPnl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (issue != null) Text(issue, style: Theme.of(context).textTheme.bodySmall),
        if (value.usd != null && !value.fresh)
          Text(l10n.collateralStale, style: const TextStyle(color: AppColors.warning)),
        _CollateralDetails(asset: asset.asset, value: value, receivedAt: accountReceivedAt),
      ],
    );
  }
}

String _amount(Decimal? number, String unit) =>
    number == null ? '—' : '${marketNumber(number)} $unit';

class _CollateralDetails extends StatelessWidget {
  const _CollateralDetails({required this.asset, required this.value, required this.receivedAt});
  final String asset;
  final AssetCollateralValue value;
  final DateTime receivedAt;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.transparent,
      child: ExpansionTile(
        key: ValueKey('asset-collateral-details-$asset'),
        tilePadding: EdgeInsets.zero,
        title: Text(l10n.collateralCalculation),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.collateralFormula),
          if (value.markTime != null)
            Text(l10n.collateralMarkTime(value.markTime!.toUtc().toIso8601String())),
          ValueRow(l10n.collateralCrossEquity, _amount(value.equity, asset)),
          ValueRow(l10n.collateralBidRate, _amount(value.quote?.bidRate, 'USD/$asset')),
          ValueRow(l10n.collateralAskRate, _amount(value.quote?.askRate, 'USD/$asset')),
          Text(l10n.collateralAccountTime(receivedAt.toUtc().toIso8601String())),
          if (value.quote != null)
            Text(l10n.collateralRateTime(value.quote!.time.toUtc().toIso8601String())),
          Text(l10n.collateralScope, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

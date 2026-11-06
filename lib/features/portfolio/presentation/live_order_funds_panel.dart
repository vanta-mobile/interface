import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/live_order.dart';

class LiveOrderFundsPanel extends StatelessWidget {
  const LiveOrderFundsPanel({super.key, required this.data, this.historical = false});
  final LiveOrderContext data;
  final bool historical;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), funds = data.funds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (funds == null) Text(l10n.liveOrderReadFunds),
        if (data.fundsFailure case final failure?)
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (funds != null) ...[
          ValueRow(
            l10n.assetModeCurrentSetting,
            funds.assetMode == FuturesAssetMode.multi ? l10n.assetModeMulti : l10n.assetModeSingle,
          ),
          ValueRow(
            l10n.liveOrderAvailableUsdt,
            funds.account.availableBalance == null ? '—' : '${funds.account.availableBalance} USDT',
            key: const Key('live-order-available'),
          ),
          Text(l10n.accountSnapshotTime(funds.account.receivedAt.toUtc().toIso8601String())),
          Text(l10n.liveOrderFundsScope, style: Theme.of(context).textTheme.bodySmall),
          if (historical)
            Text(l10n.liveOrderFundsHistorical, style: const TextStyle(color: AppColors.warning)),
          if (funds.account.canTrade == false)
            Text(l10n.liveOrderTradingDisabled, style: const TextStyle(color: AppColors.negative)),
          if (funds.assetMode == FuturesAssetMode.multi) ...[
            Text(l10n.liveOrderFundsMultiHint, style: Theme.of(context).textTheme.bodySmall),
            ExpansionTile(
              key: const Key('live-order-collateral'),
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.liveOrderFundsAssets),
              children: [
                for (final asset in funds.account.assets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(asset.asset),
                        ValueRow(
                          l10n.available,
                          asset.availableBalance == null
                              ? '—'
                              : '${asset.availableBalance} ${asset.asset}',
                        ),
                        Text(
                          asset.marginAvailable == true
                              ? l10n.accountCollateralEligible
                              : asset.marginAvailable == false
                              ? l10n.accountCollateralIneligible
                              : l10n.liveOrderCollateralUnknown,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class LiveOrderCostPreview extends StatelessWidget {
  const LiveOrderCostPreview({super.key, required this.data, required this.draft});
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quantity = data.estimatedOpeningQuantity(draft),
        margin = data.estimatedOpeningMargin(draft);
    final available = data.funds?.account.availableBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          l10n.liveOrderOpeningQuantity,
          quantity == null ? '—' : '$quantity ${data.rules.baseAsset}',
          key: const Key('live-order-opening-quantity'),
        ),
        ValueRow(
          l10n.liveOrderOpeningMargin,
          margin == null ? '—' : '$margin ${data.rules.quoteAsset}',
          key: const Key('live-order-opening-margin'),
        ),
        Text(
          draft.trigger == null
              ? l10n.liveOrderMarginEstimateHint
              : l10n.liveOrderConditionalEstimateHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (data.funds?.assetMode == FuturesAssetMode.single &&
            margin != null &&
            available != null &&
            margin > available)
          Text(l10n.liveOrderMarginAboveBalance, style: const TextStyle(color: AppColors.warning)),
      ],
    );
  }
}

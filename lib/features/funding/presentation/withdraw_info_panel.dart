import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/domain/market_precision.dart';
import '../../portfolio/presentation/account_read_controls.dart';
import '../../portfolio/presentation/account_snapshot_status.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/withdraw_info_provider.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';

String fundingAmount(Decimal? value, String unit) =>
    value == null ? '—' : '${marketNumber(value)} $unit';

class WithdrawInfoPanel extends ConsumerWidget {
  const WithdrawInfoPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(withdrawInfoProvider);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final controller = ref.read(withdrawInfoProvider.notifier);
    final info = state.account;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fundingWithdrawLimits, style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.fundingWithdrawScope),
          if (address != null) SelectableText(address, key: const Key('withdraw-info-address')),
          AccountReadControls(
            state: state,
            onRead: controller.refresh,
            buttonKey: const Key('withdraw-info-refresh'),
            initialLabel: l10n.fundingReadLimits,
            refreshLabel: l10n.fundingRefreshLimits,
          ),
          if (state.busy)
            TextButton(
              key: const Key('withdraw-info-stop'),
              onPressed: controller.stopRead,
              child: Text(l10n.subaccountStopWaiting),
            ),
          AccountSnapshotStatus(
            state: state,
            timeKey: const Key('withdraw-info-time'),
            staleKey: const Key('withdraw-info-stale'),
          ),
          if (info != null) ...[
            ValueRow(l10n.fundingUserDailyUsd, fundingAmount(info.userDailyLimitUsd, 'USD')),
            ValueRow(
              l10n.fundingUserRemainingUsd,
              fundingAmount(info.userRemainingDailyLimitUsd, 'USD'),
            ),
            ValueRow(l10n.fundingGlobalDailyUsd, fundingAmount(info.totalDailyLimitUsd, 'USD')),
            ValueRow(
              l10n.fundingGlobalRemainingUsd,
              fundingAmount(info.totalRemainingDailyLimitUsd, 'USD'),
            ),
            if (info.assets.isEmpty) Text(l10n.fundingNoWithdrawBalances),
          ],
        ],
      ),
    );
  }
}

class WithdrawAssetLimits extends ConsumerWidget {
  const WithdrawAssetLimits({super.key, required this.asset, required this.market});
  final FundingAsset asset;
  final TransferMarket market;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(withdrawInfoProvider);
    final balance = state.account?.assets[asset.asset], chain = balance?.chains[asset.chainId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.fundingAssetTotal, fundingAmount(balance?.total(market), asset.asset)),
        ValueRow(l10n.fundingChainMaximum, fundingAmount(chain?.maximum(market), asset.asset)),
        ValueRow(l10n.fundingChainLimit, fundingAmount(chain?.chainLimit, asset.asset)),
        ValueRow(l10n.fundingAssetDailyUsd, fundingAmount(balance?.dailyLimitUsd, 'USD')),
        ValueRow(l10n.fundingSnapshotFee, fundingAmount(chain?.fee, asset.asset)),
        if (balance == null || chain == null) Text(l10n.fundingLimitsUnavailable),
        Text(l10n.fundingLimitUnits, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

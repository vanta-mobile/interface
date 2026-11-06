import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/funding_fee_provider.dart';
import '../domain/funding_fee.dart';
import '../domain/transfer_history.dart';
import 'withdraw_info_panel.dart';

class FundingFeeEntry extends StatelessWidget {
  const FundingFeeEntry({super.key, required this.query});
  final FundingFeeQuery query;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: Key('funding-fee-entry-${query.chainId}-${query.asset}'),
    onPressed: () =>
        Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => FundingFeeScreen(query: query))),
    child: Text(AppLocalizations.of(context).fundingFeeCheck),
  );
}

class FundingFeeScreen extends ConsumerWidget {
  const FundingFeeScreen({super.key, required this.query});
  final FundingFeeQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(fundingFeeProvider(query));
    final quote = state.quote;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fundingFeeTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('funding-fee-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.fundingFeeScope),
            const SizedBox(height: 12),
            ValueRow(
              l10n.fundingAccount,
              query.market == TransferMarket.spot
                  ? l10n.transferSpotMarket
                  : l10n.transferPerpMarket,
            ),
            ValueRow(l10n.fundingNetwork, switch (query.chainId) {
              1 => l10n.fundingEthereum,
              56 => l10n.fundingBnbChain,
              42161 => l10n.fundingArbitrum,
              _ => query.chainId.toString(),
            }),
            SelectableText(query.asset),
            const SizedBox(height: 12),
            if (state.loading) ...[const LinearProgressIndicator(), Text(l10n.fundingFeeLoading)],
            if (state.failureKey case final key?)
              Text(
                apiErrorText(
                  context,
                  key,
                  state.errorDetails,
                  fallbackText: key == 'fundingFeeFailed'
                      ? l10n.fundingFeeFailed
                      : tr(context, key),
                ),
                style: const TextStyle(color: AppColors.negative),
              ),
            if (state.stale)
              Text(
                l10n.fundingFeeStale,
                key: const Key('funding-fee-stale'),
                style: const TextStyle(color: AppColors.warning),
              ),
            if (quote != null) ...[
              ValueRow(l10n.fundingFeeAsset, fundingAmount(quote.assetFee, query.asset)),
              ValueRow(l10n.fundingFeeUsd, fundingAmount(quote.usdFee, 'USD')),
              ValueRow(l10n.fundingFeeAssetPrice, fundingAmount(quote.assetPriceUsd, 'USD')),
              Text(
                l10n.fundingFeeTime(
                  DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
                      .add_Hms()
                      .format(quote.receivedAt.toLocal()),
                ),
                key: const Key('funding-fee-time'),
              ),
            ],
            OutlinedButton(
              key: const Key('funding-fee-refresh'),
              onPressed: state.loading
                  ? null
                  : () => ref.read(fundingFeeProvider(query).notifier).refresh(),
              child: Text(l10n.fundingFeeRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

import '../../portfolio/presentation/rebalance_entry.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/funding_catalog_provider.dart';
import '../application/withdraw_info_provider.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';
import 'funding_assets.dart';
import 'transfer_history_screen.dart';
import 'withdraw_info_panel.dart';
import 'deposit_approval_recovery_screen.dart';

void openFundingInfo(BuildContext context, TransferMarket market) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => FundingInfoScreen(initialMarket: market)));

class FundingInfoEntry extends StatelessWidget {
  const FundingInfoEntry({super.key, required this.market});
  final TransferMarket market;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('funding-info-entry'),
    onPressed: () => openFundingInfo(context, market),
    icon: const Icon(Icons.account_balance_outlined),
    label: Text(AppLocalizations.of(context).fundingInfoTitle),
  );
}

class FundingInfoScreen extends ConsumerStatefulWidget {
  const FundingInfoScreen({super.key, required this.initialMarket});
  final TransferMarket initialMarket;
  @override
  ConsumerState<FundingInfoScreen> createState() => _FundingInfoScreenState();
}

class _FundingInfoScreenState extends ConsumerState<FundingInfoScreen> {
  late TransferMarket market = widget.initialMarket;
  FundingOperation operation = FundingOperation.deposit;
  int chainId = 56;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), query = FundingCatalogQuery(market, operation);
    final state = ref.watch(fundingCatalogProvider(query));
    if (operation == FundingOperation.withdraw) {
      // Retain the signed snapshot across gaps between lazily built controls
      // and asset cards; individual consumers still observe their own values.
      ref.watch(withdrawInfoProvider.select((_) => null));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fundingInfoTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('funding-info-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            const DepositApprovalRecoveryNotice(),
            const RebalanceRecoveryNotice(),
            Text(l10n.fundingInfoScope),
            const SizedBox(height: 12),
            _Selectors(
              market: market,
              operation: operation,
              chainId: chainId,
              onMarket: (value) => setState(() => market = value),
              onOperation: (value) => setState(() => operation = value),
              onChain: (value) => setState(() => chainId = value),
            ),
            const SizedBox(height: 12),
            Text(l10n.fundingEvmScope, style: Theme.of(context).textTheme.bodySmall),
            _CatalogStatus(
              state: state,
              onRefresh: () => ref.read(fundingCatalogProvider(query).notifier).refresh(),
            ),
            if (operation == FundingOperation.withdraw) ...[
              const SizedBox(height: 16),
              const WithdrawInfoPanel(),
              if (market == TransferMarket.perp) const RebalanceEntry(),
            ],
            if (state.catalog case final catalog?) ...[
              const SizedBox(height: 16),
              FundingAssets(key: ValueKey((query, chainId)), catalog: catalog, chainId: chainId),
            ],
            const TransferHistoryEntry(),
          ],
        ),
      ),
    );
  }
}

class _Selectors extends StatelessWidget {
  const _Selectors({
    required this.market,
    required this.operation,
    required this.chainId,
    required this.onMarket,
    required this.onOperation,
    required this.onChain,
  });
  final TransferMarket market;
  final FundingOperation operation;
  final int chainId;
  final ValueChanged<TransferMarket> onMarket;
  final ValueChanged<FundingOperation> onOperation;
  final ValueChanged<int> onChain;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.fundingAccount),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TransferMarket>(
              key: const Key('funding-market'),
              value: market,
              isExpanded: true,
              items: [
                for (final value in TransferMarket.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == TransferMarket.spot
                          ? l10n.transferSpotMarket
                          : l10n.transferPerpMarket,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onMarket(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final value in FundingOperation.values)
              ChoiceChip(
                key: Key('funding-operation-${value.name}'),
                label: Text(
                  value == FundingOperation.deposit ? l10n.fundingDeposit : l10n.fundingWithdraw,
                ),
                selected: operation == value,
                onSelected: (_) => onOperation(value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.fundingNetwork),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const Key('funding-network'),
              value: chainId,
              isExpanded: true,
              items: [
                for (final id in fundingEvmChainIds)
                  DropdownMenuItem(
                    value: id,
                    child: Text(switch (id) {
                      1 => l10n.fundingEthereum,
                      56 => l10n.fundingBnbChain,
                      _ => l10n.fundingArbitrum,
                    }),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChain(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({required this.state, required this.onRefresh});
  final FundingCatalogState state;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loading) ...[const LinearProgressIndicator(), Text(l10n.fundingCatalogLoading)],
        if (state.failureKey case final key?)
          Text(
            key == 'fundingCatalogFailed' ? l10n.fundingCatalogFailed : tr(context, key),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (state.stale)
          Text(l10n.fundingCatalogStale, style: const TextStyle(color: AppColors.warning)),
        if (state.catalog case final catalog?)
          Text(l10n.fundingCatalogTime(catalog.receivedAt.toIso8601String())),
        OutlinedButton(
          key: const Key('funding-catalog-refresh'),
          onPressed: state.loading ? null : onRefresh,
          child: Text(l10n.fundingCatalogRefresh),
        ),
      ],
    );
  }
}

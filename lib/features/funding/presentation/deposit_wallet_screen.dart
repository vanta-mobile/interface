import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/deposit_wallet_provider.dart';
import '../application/deposit_gas_provider.dart';
import '../domain/deposit_wallet.dart';
import '../domain/transfer_history.dart';
import 'deposit_amount_form.dart';
import 'deposit_wallet_panel.dart';
import 'withdraw_info_panel.dart';
import 'deposit_approval_recovery_screen.dart';
import 'deposit_submission_recovery_screen.dart';

class DepositWalletEntry extends StatelessWidget {
  const DepositWalletEntry({super.key, required this.query});
  final DepositWalletQuery query;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: Key('deposit-wallet-entry-${query.asset.chainId}-${query.asset.asset}'),
    onPressed: () =>
        Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => DepositWalletScreen(query: query))),
    child: Text(AppLocalizations.of(context).depositPrecheckTitle),
  );
}

class DepositWalletScreen extends ConsumerWidget {
  const DepositWalletScreen({super.key, required this.query});
  final DepositWalletQuery query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), asset = query.asset;
    // Keep the snapshot alive between lazily built read controls and amount form.
    ref.watch(depositWalletProvider(query).select((_) => null));
    ref.watch(depositGasProvider(query).select((_) => null));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.depositPrecheckTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('deposit-wallet-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            const DepositApprovalRecoveryNotice(),
            const DepositSubmissionRecoveryNotice(),
            Text(l10n.depositPrecheckScope),
            ValueRow(
              l10n.fundingAccount,
              query.market == TransferMarket.spot
                  ? l10n.transferSpotMarket
                  : l10n.transferPerpMarket,
            ),
            ValueRow(l10n.fundingNetwork, switch (asset.chainId) {
              1 => l10n.fundingEthereum,
              56 => l10n.fundingBnbChain,
              _ => l10n.fundingArbitrum,
            }),
            SelectableText(asset.asset),
            ValueRow(l10n.depositMinimum, fundingAmount(asset.minimumDeposit, asset.asset)),
            const SizedBox(height: 12),
            DepositWalletPanel(query: query),
            const SizedBox(height: 16),
            DepositAmountForm(query: query),
          ],
        ),
      ),
    );
  }
}

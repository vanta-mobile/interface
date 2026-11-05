import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';

class DepositGasDetails extends StatelessWidget {
  const DepositGasDetails({super.key, required this.quote});
  final DepositGasQuote quote;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), transaction = quote.transaction;
    final native = transaction.query.asset.chainId == 56 ? 'BNB' : 'ETH';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (transaction.kind) {
          DepositTransactionKind.resetApproval => l10n.depositGasReset,
          DepositTransactionKind.approve => l10n.depositGasApprove,
          DepositTransactionKind.deposit => l10n.depositGasDeposit,
        }, key: const Key('deposit-gas-step')),
        if (transaction.kind == DepositTransactionKind.resetApproval)
          Text(l10n.depositGasResetHint),
        SelectableText(quote.address),
        if (transaction.query.verifiedMinimumDeposit != null) ...[
          Text(l10n.depositVerifiedMinimum),
          SelectableText(
            '${transaction.query.verifiedMinimumDeposit} ${transaction.query.asset.asset}',
          ),
        ],
        ValueRow(
          l10n.depositGasAmount,
          '${depositQuantity(transaction.amountUnits, transaction.query.asset.decimals)} ${transaction.query.asset.asset}',
        ),
        Text(l10n.depositGasTarget),
        SelectableText(transaction.to),
        ValueRow(l10n.depositGasValue, '${depositQuantity(transaction.value, 18)} $native'),
        ValueRow(l10n.depositGasEstimatedUnits, '${quote.estimatedGas}'),
        ValueRow(l10n.depositGasLimit, '${quote.gasLimit}'),
        ValueRow(l10n.depositGasPrice, '${quote.gasPrice}'),
        ValueRow(l10n.depositGasReserve, '${depositQuantity(quote.feeReserve, 18)} $native'),
        ValueRow(l10n.depositGasTotal, '${depositQuantity(quote.nativeRequired, 18)} $native'),
        Text(l10n.depositGasReserveHint),
        Text(l10n.accountSnapshotTime(quote.receivedAt.toUtc().toIso8601String())),
      ],
    );
  }
}

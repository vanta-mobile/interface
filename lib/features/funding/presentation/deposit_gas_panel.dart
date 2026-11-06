import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/deposit_gas_provider.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_messages.dart';
import 'deposit_approval_panel.dart';
import 'deposit_gas_details.dart';

class DepositGasPanel extends ConsumerWidget {
  const DepositGasPanel({
    super.key,
    required this.query,
    required this.amount,
    required this.canEstimate,
  });
  final DepositWalletQuery query;
  final String amount;
  final bool canEstimate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(depositGasProvider(query));
    final controller = ref.read(depositGasProvider(query).notifier), quote = state.account;
    final currentUnits = checkDepositAmount(
      input: amount,
      query: query,
      snapshot: quote?.wallet,
      stale: false,
    ).units;
    final amountChanged = quote != null && currentUnits != quote.transaction.amountUnits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(l10n.depositGasTitle, style: Theme.of(context).textTheme.titleMedium),
        Text(l10n.depositGasScope),
        OutlinedButton(
          key: const Key('deposit-gas-estimate'),
          onPressed: !canEstimate || state.busy ? null : () => controller.estimate(amount),
          child: Text(l10n.depositGasEstimate),
        ),
        if (state.busy) ...[
          const LinearProgressIndicator(),
          TextButton(
            key: const Key('deposit-gas-stop'),
            onPressed: controller.stop,
            child: Text(l10n.subaccountStopWaiting),
          ),
        ],
        if (state.failure case final error?)
          Text(
            apiErrorText(
              context,
              error.key,
              error.details,
              fallbackText: depositMessage(context, error.key),
            ),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (quote != null) ...[
          if (state.stale)
            Text(l10n.depositReadStale, style: const TextStyle(color: AppColors.warning)),
          if (amountChanged)
            Text(l10n.depositGasChangedAmount, style: const TextStyle(color: AppColors.warning)),
          DepositGasDetails(quote: quote),
          if (quote.transaction.kind != DepositTransactionKind.deposit)
            DepositApprovalPanel(
              query: query,
              amount: amount,
              canPrepare: canEstimate && !state.stale && !amountChanged,
            ),
        ],
      ],
    );
  }
}

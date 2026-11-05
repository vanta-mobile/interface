import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../core/strings.dart';
import '../application/wallet_operation_provider.dart';
import '../domain/wallet_operation.dart';

String walletOperationLabel(BuildContext context, WalletOperationKind k) {
  final l = AppLocalizations.of(context);
  return switch (k) {
    WalletOperationKind.createSubaccount => l.subaccountCreate,
    WalletOperationKind.freezeSubaccount => l.subaccountFreeze,
    WalletOperationKind.unfreezeSubaccount => l.subaccountUnfreeze,
    WalletOperationKind.subaccountTransfer => l.subaccountTransfer,
    WalletOperationKind.withdrawal => l.withdrawalSubmit,
    WalletOperationKind.isolatedMargin => l.marginAdjustTitle,
  };
}

String walletOperationTermValue(BuildContext context, String key, String value) {
  final l = AppLocalizations.of(context);
  String market(String v) =>
      v == 'SPOT' || v == 'spot' ? l.transferSpotMarket : l.transferPerpMarket;
  if (key == 'market') return market(value);
  if (key == 'direction') {
    final parts = value.split('_');
    return '${market(parts[0])} → ${market(parts[1])}';
  }
  return value;
}

class WalletOperationHistory extends ConsumerWidget {
  const WalletOperationHistory({super.key, required this.withdrawals});
  final bool withdrawals;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), s = ref.watch(walletOperationStorageProvider);
    final records = ref
        .watch(currentWalletOperationsProvider)
        .where((r) => (r.kind == WalletOperationKind.withdrawal) == withdrawals)
        .toList()
        .reversed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.walletOperationHistory, style: Theme.of(context).textTheme.titleMedium),
        if (!s.ready || s.failed) Text(l.walletOperationStorage),
        OutlinedButton(
          onPressed: ref.read(walletOperationStorageProvider.notifier).reload,
          child: Text(l.walletOperationReload),
        ),
        for (final r in records)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(walletOperationLabel(context, r.kind)),
                  Text(r.acknowledged ? l.walletOperationAcknowledged : l.walletOperationUnknown),
                  SelectableText(r.preparedAt.toLocal().toString()),
                  SelectableText(r.address),
                  for (final term in r.terms.entries)
                    SelectableText(
                      '${tr(context, switch (term.key) {
                        'child' => 'subaccountChildAddress',
                        'name' => 'subaccountName',
                        'from' => 'subaccountFrom',
                        'to' => 'subaccountTo',
                        'amount' => 'internalTransferAmount',
                        'asset' => 'internalTransferAsset',
                        'direction' => 'subaccountTransferDirection',
                        'fee' => 'withdrawalFee',
                        'chain' => 'withdrawalChain',
                        'market' => 'withdrawalMarket',
                        'receiver' => 'withdrawalReceiver',
                        _ => 'subaccountId',
                      })}: ${walletOperationTermValue(context, term.key, term.value)}',
                    ),
                  if (r.reference != null) SelectableText(r.reference!),
                  SelectableText('${l.walletOperationReference}: ${r.nonce}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

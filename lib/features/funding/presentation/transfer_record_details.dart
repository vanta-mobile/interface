import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../notifications/presentation/notification_field.dart';
import '../domain/transfer_history.dart';

String transferMarketLabel(AppLocalizations l10n, TransferMarket market) =>
    market == TransferMarket.spot ? l10n.transferSpotMarket : l10n.transferPerpMarket;

String transferNetworkLabel(AppLocalizations l10n, int chainId) => switch (chainId) {
  1 => l10n.transferNetworkEthereum,
  56 => l10n.transferNetworkBnb,
  42161 => l10n.transferNetworkArbitrum,
  _ => l10n.transferUnknownNetwork(chainId.toString()),
};

class TransferRecordDetails extends StatelessWidget {
  const TransferRecordDetails(this.record, {super.key});
  final TransferRecord record;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), r = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.transferRecordScope),
        NotificationField(l10n.transferRecordId, r.id),
        NotificationField(l10n.transferMarketLabel, transferMarketLabel(l10n, r.market)),
        NotificationField(
          l10n.transferTypeLabel,
          r.type == TransferType.deposit ? l10n.transferDeposit : l10n.transferWithdraw,
        ),
        NotificationField(l10n.openOrdersStatus, l10n.transferStatus(r.status.name)),
        NotificationField(l10n.quantity, '${r.amount} ${r.asset}'),
        NotificationField(l10n.transferNetwork, transferNetworkLabel(l10n, r.chainId)),
        NotificationField(l10n.transferChainId, r.chainId.toString()),
        NotificationField(l10n.transferHash, r.txHash ?? l10n.transferHashUnknown),
        NotificationField(l10n.transferRecordTime, r.recordTime.toIso8601String()),
      ],
    );
  }
}

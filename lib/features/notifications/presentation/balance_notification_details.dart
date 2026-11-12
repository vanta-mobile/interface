import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../funding/presentation/transfer_history_components.dart' show historyTime;
import '../domain/account_notification.dart';
import 'notification_detail_components.dart';

class BalanceNotificationDetails extends StatelessWidget {
  const BalanceNotificationDetails(this.event, {super.key});
  final BalanceNotification event;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), e = event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        NotificationDetailSummary(
          title: l.notificationBalanceTitle,
          value: l.notificationAssetsChanged(e.balances.length),
        ),
        NotificationDetailRow(l.assetHistoryTime, historyTime(e.eventTime)),
        NotificationDetailSection(l.notificationBalanceChanges),
        for (final balance in e.balances)
          NotificationDetailCard(
            spacing: 12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      balance.asset,
                      style: NotificationTypography.detailSection,
                    ),
                  ),
                  if (balance.change != null) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: SelectableText(
                        notificationAmount(balance.change!, balance.asset, l, signed: true),
                        textAlign: TextAlign.end,
                        style: NotificationTypography.detailSection.copyWith(
                          color: notificationPnlColor(balance.change!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              NotificationDetailRow(
                l.notificationWalletBalance,
                notificationAmount(balance.walletBalance, balance.asset, l),
              ),
              NotificationDetailRow(
                l.accountCrossWalletBalance,
                notificationAmount(balance.crossWalletBalance, balance.asset, l),
              ),
            ],
          ),
      ],
    );
  }
}

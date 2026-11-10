import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/account_entry.dart';
import 'account_components.dart';

class SubaccountFreezeSheet extends StatelessWidget {
  const SubaccountFreezeSheet({super.key, required this.entry});
  final AccountEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.freezeRequested ? l.accountsUnfreeze : l.accountsFreezeTitle(entry.name),
              style: AccountTypography.heading,
            ),
            const SizedBox(height: 12),
            Text(
              entry.freezeRequested ? l.accountsUnfreezeNotice : l.accountsFreezeNotice,
              style: AccountTypography.secondary,
            ),
            const SizedBox(height: 8),
            PortfolioCard(
              border: false,
              radius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: AccountTypography.body),
                  const SizedBox(height: 2),
                  Semantics(
                    onLongPress: () => copyAccountAddress(entry.address),
                    child: GestureDetector(
                      onLongPress: () => copyAccountAddress(entry.address),
                      child: Text(
                        shortAccountAddress(entry.address),
                        style: AccountTypography.caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(l.accountsReviewOrders, style: AccountTypography.caption),
            const SizedBox(height: 8),
            AccountAction(
              key: const Key('account-freeze-confirm'),
              label: entry.freezeRequested ? l.accountsUnfreeze : l.accountsFreeze,
              danger: !entry.freezeRequested,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            AccountAction(
              label: tr(context, 'cancel'),
              primary: false,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

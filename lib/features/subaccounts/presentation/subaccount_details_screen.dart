import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/account_entries_provider.dart';
import '../application/subaccount_list_provider.dart';
import '../domain/account_entry.dart';
import 'account_components.dart';
import 'account_balance_text.dart';
import '../application/account_balances_provider.dart';
import 'account_switch_screen.dart';
import 'subaccount_freeze_sheet.dart';
import 'subaccount_freeze_authorization.dart';

class SubaccountDetailsScreen extends ConsumerWidget {
  const SubaccountDetailsScreen({super.key, required this.address});
  final String address;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), entries = ref.watch(accountEntriesProvider);
    final entry = entries
        .where((e) => e.address.toLowerCase() == address.toLowerCase())
        .firstOrNull;
    final manage = ref.watch(canManageAccountsProvider);
    if (entry == null) {
      return AccountsPage(title: l.accountsDetailsTitle, children: [Text(l.authWalletChanged)]);
    }
    return AccountsPage(
      title: l.accountsDetailsTitle,
      actions: [copyAccountButton(context, entry.address)],
      onRefresh: () async {
        await Future.wait([
          if (manage) ref.read(subaccountListProvider.notifier).refresh(),
          ref.read(accountBalancesProvider.notifier).refresh(),
        ]);
      },
      footer: [
        AccountAction(
          key: const Key('account-details-primary'),
          label: entry.freezeRequested ? l.accountsUnfreeze : l.accountsSwitchTo,
          onPressed: entry.freezeRequested
              ? (manage ? () => _freeze(context, entry) : null)
              : () => Navigator.of(
                  context,
                ).push<void>(MaterialPageRoute(builder: (_) => AccountSwitchScreen(target: entry))),
        ),
      ],
      children: [
        AccountContext(entry.owner),
        PortfolioCard(
          border: false,
          radius: 14,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    const PortfolioIcon(
                      'account-large.svg',
                      size: 36,
                      color: PortfolioColors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.name, style: PortfolioTypography.heading),
                          const SizedBox(height: 2),
                          Text(
                            entry.freezeRequested
                                ? '${l.subaccountChild} · ${l.accountsFreezeRequested}'
                                : l.subaccountChild,
                            style: PortfolioTypography.caption.copyWith(
                              color: entry.freezeRequested
                                  ? PortfolioColors.negative
                                  : PortfolioColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AccountAddressRow(l.accountsAddress, entry.address),
              const SizedBox(height: 12),
              AccountAddressRow(l.accountsOwnerWallet, entry.owner),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PortfolioCard(
          border: false,
          radius: 14,
          child: AccountBalanceRow(l.accountsAssets, entry.address),
        ),
        const SizedBox(height: 16),
        if (entry.freezeRequested) ...[
          AccountNotice(l.accountsFrozenNotice, warning: true),
          Text(l.accountsFreezeBoundary, style: PortfolioTypography.caption),
        ] else ...[
          AccountAction(
            key: const Key('account-freeze-entry'),
            label: l.accountsFreeze,
            primary: false,
            danger: true,
            onPressed: manage ? () => _freeze(context, entry) : null,
          ),
          const SizedBox(height: 16),
          AccountNotice(l.accountsIndependentKey),
        ],
      ],
    );
  }

  Future<void> _freeze(BuildContext context, AccountEntry entry) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: PortfolioColors.inset,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: PortfolioColors.line),
      ),
      builder: (_) => SubaccountFreezeSheet(entry: entry),
    );
    if (confirmed == true && context.mounted) {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => SubaccountFreezeAuthorization(entry: entry)));
    }
  }
}

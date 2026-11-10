import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/account_entries_provider.dart';
import '../application/generated_subaccount_provider.dart';
import '../application/subaccount_list_provider.dart';
import '../domain/account_entry.dart';
import '../domain/generated_subaccount.dart';
import '../domain/subaccount_directory.dart';
import 'account_components.dart';
import 'account_balance_text.dart';
import '../application/account_balances_provider.dart';
import 'create_subaccount_screen.dart';
import 'subaccount_backup_screen.dart';
import 'subaccount_details_screen.dart';
import '../../../core/presentation/status_view.dart';

class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), directory = ref.watch(subaccountListProvider);
    final entries = ref.watch(accountEntriesProvider).where((a) => a.roleKnown && !a.main).toList();
    final owner = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final wallets = ref.watch(generatedWalletsProvider);
    ref.watch(accountBalancesProvider);
    final manage = ref.watch(canManageAccountsProvider);
    final count = directory.account?.childCount;
    Future<void> refresh() async {
      final identity = ref.read(authProvider).identity;
      final vault = ref.refresh(generatedWalletsProvider.future);
      await Future.wait([
        ref.read(subaccountListProvider.notifier).refresh(),
        vault.then<void>((_) {}, onError: (Object _) {}),
      ]);
      if (!context.mounted || !identical(ref.read(authProvider).identity, identity)) return;
      // Reload key metadata first, then await the balance batch it starts.
      await ref.read(accountBalancesProvider.notifier).refresh();
    }

    return AccountsPage(
      title: l.accountsListTitle,
      onRefresh: refresh,
      footer: [
        AccountAction(
          key: const Key('accounts-create-entry'),
          label: l.accountsCreate,
          onPressed: manage && count != null && count < 10 && !directory.busy
              ? () => Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => const CreateSubaccountScreen()))
              : null,
        ),
      ],
      children: [
        if (owner != null && manage) AccountContext(owner),
        Row(
          children: [
            Expanded(child: Text(l.accountsYourChildren, style: PortfolioTypography.section)),
            Text(
              '${count ?? '—'} / 10',
              style: PortfolioTypography.caption.copyWith(color: PortfolioColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(l.accountsSeparateStrategies, style: AccountTypography.secondary),
        const SizedBox(height: 16),
        if (directory.account == null)
          AccountAction(
            key: const Key('subaccount-list-refresh'),
            label: l.subaccountRead,
            busy: directory.busy,
            onPressed: ref.read(authProvider).needsWalletConnection
                ? () => showAccountSheet(context)
                : ref.watch(canInspectAccountsProvider)
                ? refresh
                : null,
          ),
        if (directory.failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              accountErrorText(context, directory.failure!),
              style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
            ),
          ),

        if (!ref.watch(canInspectAccountsProvider)) AccountNotice(l.subaccountMasterRequired),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AccountCard(entry: entry),
          ),
        // The remote directory does not identify wallet addresses. Keep its
        // returned IDs copyable; never join those IDs to local wallets by name.
        if (directory.account != null)
          for (final account in directory.account!.accounts.where((a) => !a.isParent))
            Padding(padding: const EdgeInsets.only(bottom: 12), child: _DirectoryCard(account)),
        if (count == 0 && entries.isEmpty) StatusEmptyView(message: l.subaccountNoChildren),
        for (final wallet in wallets.value ?? const <GeneratedSubaccount>[])
          if (wallet.owner.toLowerCase() == owner?.toLowerCase() && !wallet.backedUp)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AccountAction(
                label: '${l.accountsBackupPending} · ${wallet.name}',
                primary: false,
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => SubaccountBackupScreen(wallet: wallet)),
                ),
              ),
            ),
        if (wallets.hasError) AccountNotice(l.subaccountSecureStorageFailed, warning: true),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.entry});
  final AccountEntry entry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        key: ValueKey('account-details-${entry.address}'),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => SubaccountDetailsScreen(address: entry.address)),
        ),
        child: PortfolioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PortfolioIcon('account.svg'),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.name, style: AccountTypography.name)),
                  const PortfolioIcon('chevron-right.svg', size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(shortAccountAddress(entry.address), style: PortfolioTypography.caption),
              const SizedBox(height: 20),
              AccountBalanceRow(l.accountsBalance, entry.address),
              const SizedBox(height: 8),
              AccountValueRow(
                l.accountsStatus,
                entry.freezeRequested ? l.accountsFreezeRequested : l.accountsStatusUnverified,
                color: entry.freezeRequested ? PortfolioColors.negative : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard(this.account);
  final AsterSubaccount account;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.name.isEmpty ? l.subaccountUnnamed : account.name,
            style: PortfolioTypography.heading,
          ),
          AccountValueRow(l.subaccountId, '${account.accountId}', copyable: true),
          Text(l.accountsUnknownAddress, style: PortfolioTypography.caption),
        ],
      ),
    );
  }
}

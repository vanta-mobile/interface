import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/portfolio_overview_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/account_entries_provider.dart';
import '../application/generated_subaccount_provider.dart';
import '../domain/account_entry.dart';
import 'account_components.dart';

class AccountSwitchScreen extends ConsumerStatefulWidget {
  const AccountSwitchScreen({super.key, required this.target});
  final AccountEntry target;
  @override
  ConsumerState<AccountSwitchScreen> createState() => _AccountSwitchScreenState();
}

class _AccountSwitchScreenState extends ConsumerState<AccountSwitchScreen> {
  bool busy = false;
  String? failure;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), active = ref.watch(activeAccountEntryProvider);
    final auth = ref.watch(authProvider);
    final error =
        failure ??
        (auth.failure == null ? null : auth.failure!.reason ?? tr(context, auth.failure!.key));
    return AccountsPage(
      title: l.accountsTitle,
      canPop: !busy,
      actions: [closeAccountsButton(context, enabled: !busy)],
      footer: [
        AccountAction(
          key: const Key('account-switch-confirm'),
          label: error == null ? l.accountsSwitchConfirm : l.accountsSwitchRetry,
          busy: busy,
          onPressed: widget.target.freezeRequested || auth.busy ? null : _switch,
        ),
        const SizedBox(height: 12),
        AccountAction(
          label: tr(context, 'cancel'),
          primary: false,
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
      ],
      children: [
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PortfolioIcon('warning.svg', size: 20, color: PortfolioColors.negative),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.accountsSwitchFailed(error, active == null ? '—' : accountLabel(l, active)),
                    style: AccountTypography.caption.copyWith(color: PortfolioColors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        Text(
          l.accountsSwitchHeading(accountLabel(l, widget.target)),
          style: PortfolioTypography.heading,
        ),
        const SizedBox(height: 16),
        Text(l.accountsSwitchNotice, style: AccountTypography.secondary),
        const SizedBox(height: 36),
        PortfolioCard(
          border: false,
          radius: 14,
          child: Column(
            children: [
              AccountValueRow(l.accountsFrom, active == null ? '—' : accountLabel(l, active)),
              const SizedBox(height: 12),
              AccountValueRow(l.accountsTo, accountLabel(l, widget.target)),
              const SizedBox(height: 12),
              AccountAddressRow(l.accountsAddress, widget.target.address),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AccountNotice(l.accountsSwitchConnection),
      ],
    );
  }

  Future<void> _switch() async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    final previous = ref.read(authProvider).identity;
    try {
      final wallets = await ref.read(generatedWalletsProvider.future);
      if (!mounted || ref.read(authProvider).identity != previous) return;
      final wallet = wallets
          .where((w) => w.address.toLowerCase() == widget.target.address.toLowerCase())
          .singleOrNull;
      if (wallet != null) {
        if (!wallet.backedUp) {
          setState(() => failure = AppLocalizations.of(context).accountsBackupNotice);
          return;
        }
        await ref
            .read(authProvider.notifier)
            .switchWithConnection(ref.read(subaccountWalletStoreProvider).connection(wallet));
      } else {
        await ref.read(authProvider.notifier).switchToWallet(context, widget.target.address);
      }
      if (!mounted) return;
      final actual = ref.read(authProvider).identity?.walletAddress;
      if (actual?.toLowerCase() == widget.target.address.toLowerCase()) {
        ref.read(portfolioPreviewProvider.notifier).select(false);
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => failure = apiErrorText(context, 'subaccountSecureStorageFailed', null));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

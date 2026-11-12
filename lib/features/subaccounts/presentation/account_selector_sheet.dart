import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/application/portfolio_overview_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../application/account_entries_provider.dart';
import '../domain/account_entry.dart';
import 'account_components.dart';
import 'account_balance_text.dart';
import 'account_switch_screen.dart';

Future<void> showAccountSelector(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: tr(context, 'close'),
  barrierColor: PortfolioColors.transparent,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, animation, secondaryAnimation) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const ColoredBox(color: PortfolioColors.accountScrim),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Material(
            color: PortfolioColors.inset,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              side: BorderSide(color: PortfolioColors.line),
            ),
            child: const _AccountSelectorSheet(),
          ),
        ),
      ),
    ],
  ),
);

class _AccountSelectorSheet extends ConsumerWidget {
  const _AccountSelectorSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final external = auth.identity?.walletKind == WalletKind.external;
    final entries = ref.watch(accountEntriesProvider);
    final active = auth.identity?.walletAddress?.toLowerCase();
    final total = ref.watch(portfolioOverviewProvider).totalUsd;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        external ? l.accountsSwitchTitle : l.account,
                        style: PortfolioTypography.section,
                      ),
                    ),
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        tooltip: tr(context, 'close'),
                        onPressed: () => Navigator.pop(context),
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        padding: EdgeInsets.zero,
                        icon: const PortfolioIcon('close.svg', size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              for (final entry in entries.where(
                (e) => external || e.address.toLowerCase() == active,
              ))
                _AccountChoice(
                  entry: entry,
                  selected: entry.address.toLowerCase() == active,
                  total: entry.address.toLowerCase() == active ? portfolioUsd(total) : '—',
                  onPressed: auth.busy
                      ? null
                      : () {
                          if (entry.address.toLowerCase() == active) {
                            Navigator.pop(context);
                            return;
                          }
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push<void>(
                            MaterialPageRoute(builder: (_) => AccountSwitchScreen(target: entry)),
                          );
                        },
                ),
              AccountAction(
                key: const Key('accounts-logout'),
                label: tr(context, 'logout'),
                primary: false,
                onPressed: auth.busy
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoice extends StatelessWidget {
  const _AccountChoice({
    required this.entry,
    required this.selected,
    required this.total,
    required this.onPressed,
  });
  final AccountEntry entry;
  final bool selected;
  final String total;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? PortfolioColors.button : PortfolioColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('account-choice-${entry.address}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          onLongPress: () => copyAccountAddress(entry.address),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const PortfolioIcon('account.svg'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(accountLabel(l, entry), style: AccountTypography.body),
                      const SizedBox(height: 2),
                      Text(shortAccountAddress(entry.address), style: PortfolioTypography.caption),
                      const SizedBox(height: 2),
                      if (selected)
                        Text('${l.accountsTotalAssets} $total', style: PortfolioTypography.caption)
                      else
                        AccountBalanceRow(l.accountsBalance, entry.address),
                    ],
                  ),
                ),
                if (selected)
                  const PortfolioIcon('check-circle.svg', size: 16, color: PortfolioColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../subaccounts/domain/account_entry.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../domain/funding_catalog.dart';
import 'deposit_page.dart';
import 'funding_selection.dart';
import 'transfer_history_screen.dart';
import 'withdraw_page.dart';

void openFunding(BuildContext context, FundingOperation operation) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => FundingScreen(initialOperation: operation)));

String fundingAccountText(AppLocalizations l, AccountEntry? entry) =>
    '${entry == null ? l.account : accountLabel(l, entry)} · ${l.accountsFutures}';

List<Widget> fundingHeaderActions(BuildContext context, {bool history = true}) => [
  if (history)
    IconButton(
      key: const Key('funding-history'),
      tooltip: AppLocalizations.of(context).fundingTransactions,
      onPressed: () => openTransferHistory(context),
      icon: const PortfolioIcon('history.svg', size: 24),
    ),
  closeAccountsButton(context),
];

/// Account funding entry: Deposit and Withdraw for the current account.
class FundingScreen extends ConsumerStatefulWidget {
  const FundingScreen({super.key, this.initialOperation = FundingOperation.deposit});
  final FundingOperation initialOperation;
  @override
  ConsumerState<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends ConsumerState<FundingScreen> {
  late FundingOperation operation = widget.initialOperation;
  final deposit = FundingSelection(), withdraw = FundingSelection();
  @override
  void dispose() {
    deposit.dispose();
    withdraw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (before, after) {
        if (before == after) return;
        deposit.clear();
        withdraw.clear();
      },
    );
    void change(FundingOperation value) => setState(() => operation = value);
    return operation == FundingOperation.deposit
        ? DepositPage(selection: deposit, onOperation: change)
        : WithdrawPage(selection: withdraw, onOperation: change);
  }
}

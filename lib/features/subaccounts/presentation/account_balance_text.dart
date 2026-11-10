import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/theme.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../application/account_balances_provider.dart';

/// Preserve each asset's units instead of treating a USDT summary as total USD.
class AccountBalanceText extends ConsumerWidget {
  const AccountBalanceText(this.address, {super.key});
  final String address;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    final active = ref.watch(accountReadProvider).account;
    final account = active?.address.toLowerCase() == address.toLowerCase()
        ? active
        : balances.accounts[address.toLowerCase()];
    final failure = balances.failures[address.toLowerCase()];
    if (account == null && balances.busy) {
      return const SizedBox(width: 72, height: 16, child: ColoredBox(color: PortfolioColors.line));
    }
    final amounts = account?.assets
        .map(
          (a) => TokenAmountFormatter.format(
            DecimalValue(a.walletBalance.toString()),
            symbol: a.asset,
            display: TokenAmountDisplay.normalized,
          ),
        )
        .join(' · ');
    // Multiple asset units are not one comparable number for digit animation.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          amounts == null || amounts.isEmpty ? '—' : amounts,
          textAlign: TextAlign.right,
          style: PortfolioTypography.caption,
        ),
        if (failure != null)
          Text(
            accountErrorText(context, failure),
            textAlign: TextAlign.right,
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
          ),
      ],
    );
  }
}

class AccountBalanceRow extends StatelessWidget {
  const AccountBalanceRow(this.label, this.address, {super.key});
  final String label, address;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: PortfolioTypography.caption)),
      const SizedBox(width: 12),
      Flexible(fit: FlexFit.tight, child: AccountBalanceText(address)),
    ],
  );
}

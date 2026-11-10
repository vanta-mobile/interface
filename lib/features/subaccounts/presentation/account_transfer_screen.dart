import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/domain/decimal_value.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../application/account_entries_provider.dart';
import '../application/account_transfer_provider.dart';
import 'account_components.dart';
import 'account_transfer_fields.dart';
import 'account_transfer_selection.dart';

class AccountTransferScreen extends ConsumerStatefulWidget {
  const AccountTransferScreen({super.key});
  @override
  ConsumerState<AccountTransferScreen> createState() => _AccountTransferScreenState();
}

class _AccountTransferScreenState extends ConsumerState<AccountTransferScreen> {
  final amount = TextEditingController();
  String? target, asset;
  bool showFreezeRestriction = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), transfer = ref.watch(accountTransferProvider);
    final account = ref.watch(accountReadProvider), active = ref.watch(activeAccountEntryProvider);
    final entries = ref.watch(accountEntriesProvider);
    final destinations = entries
        .where((a) => a.address.toLowerCase() != active?.address.toLowerCase())
        .toList();
    final destination =
        destinations.where((a) => a.address == target).firstOrNull ?? destinations.firstOrNull;
    final assets = account.account?.assets ?? const [];
    final balance = assets.where((a) => a.asset == asset).firstOrNull ?? assets.firstOrNull;
    final record = transfer.submitted ?? transfer.review?.record;
    final reviewing = transfer.review != null, submitted = transfer.submitted != null;
    final from = entries.where((a) => a.address == record?.terms['from']).firstOrNull ?? active;
    final to = entries.where((a) => a.address == record?.terms['to']).firstOrNull ?? destination;
    final symbol = record?.terms['asset'] ?? balance?.asset;
    final frozen = active?.freezeRequested == true || destination?.freezeRequested == true;
    ref.listen(authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress)), (a, b) {
      if (a != b) {
        setState(() {
          amount.clear();
          target = null;
          asset = null;
        });
      }
    });
    if (showFreezeRestriction && frozen) {
      return AccountTransferUnavailable(
        onBack: () => setState(() => showFreezeRestriction = false),
      );
    }
    return AccountsPage(
      title: submitted
          ? l.accountsTransferSubmitted
          : reviewing
          ? l.accountsTransferReviewTitle
          : l.accountsTransferTitle,
      canPop: !transfer.busy,
      onRefresh: ref.read(accountReadProvider.notifier).refresh,
      footer: [
        AccountAction(
          key: const Key('accounts-transfer-submit'),
          busy: transfer.busy,
          label: submitted
              ? l.accountsBackPortfolio
              : reviewing
              ? l.accountsTransferSubmit
              : l.accountsReviewTransfer,
          onPressed: submitted
              ? () => Navigator.popUntil(context, (route) => route.isFirst)
              : reviewing
              ? () => ref.read(accountTransferProvider.notifier).confirm(transfer.review!)
              : frozen
              ? () => setState(() => showFreezeRestriction = true)
              : destination == null || balance?.availableBalance == null || amount.text.isEmpty
              ? null
              : () => ref
                    .read(accountTransferProvider.notifier)
                    .prepare(
                      target: destination.address,
                      asset: balance!.asset,
                      amount: amount.text,
                    ),
        ),
        if (reviewing && !submitted) ...[
          const SizedBox(height: 12),
          AccountAction(
            label: tr(context, 'cancel'),
            primary: false,
            onPressed: transfer.busy ? null : ref.read(accountTransferProvider.notifier).cancel,
          ),
        ],
      ],
      children: [
        if (submitted) ...[
          Text(l.accountsTransferSubmitted, style: PortfolioTypography.heading),
          const SizedBox(height: 16),
          Text(l.accountsTransferWaiting, style: AccountTypography.secondary),
          const SizedBox(height: 16),
        ],
        if (!submitted)
          AccountSelectField(
            label: l.accountsFrom,
            value: from == null ? '—' : '${accountLabel(l, from)} · ${l.accountsFutures}',
          ),
        AccountSelectField(
          key: const Key('accounts-transfer-destination'),
          label: l.accountsTo,
          showChevron: !reviewing && !submitted,
          value: to == null ? '—' : '${accountLabel(l, to)} · ${l.accountsFutures}',
          onPressed: reviewing || submitted || transfer.busy || destinations.isEmpty
              ? null
              : () async {
                  final selected = await _choose(context, {
                    for (final a in entries) a.address: accountLabel(l, a),
                  }, source: active?.address);
                  if (selected != null && mounted) {
                    setState(() {
                      target = selected;
                      showFreezeRestriction =
                          entries.any((a) => a.address == selected && a.freezeRequested) ||
                          active?.freezeRequested == true;
                    });
                  }
                },
        ),
        AccountSelectField(
          key: const Key('accounts-transfer-asset'),
          label: l.accountsAsset,
          showChevron: !reviewing && !submitted,
          value: symbol ?? '—',
          onPressed: reviewing || submitted || transfer.busy || assets.isEmpty
              ? null
              : () async {
                  final selected = await _choose(context, {
                    for (final a in assets) a.asset: a.asset,
                  });
                  if (selected != null && mounted) {
                    setState(() {
                      asset = selected;
                      amount.clear();
                    });
                  }
                },
        ),
        if (record != null)
          AccountSelectField(
            label: l.accountsAmount,
            value: TokenAmountFormatter.formatFixed(
              DecimalValue(record.terms['amount']!),
              decimals: record.terms['amount']!.contains('.')
                  ? record.terms['amount']!.split('.').last.length
                  : 0,
            ),
          )
        else
          AccountTransferAmountInput(
            controller: amount,
            enabled: !transfer.busy && !frozen,
            onChanged: (_) => setState(() {}),
          ),
        if (!reviewing && !submitted) ...[
          Row(
            children: [
              Text(l.accountsAvailable, style: PortfolioTypography.caption),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedNumberText(
                    balance?.availableBalance == null
                        ? '—'
                        : TokenAmountFormatter.format(
                            DecimalValue(balance!.availableBalance.toString()),
                            symbol: balance.asset,
                            display: TokenAmountDisplay.exact,
                          ),
                    softWrap: true,
                    style: AccountTypography.body,
                  ),
                ),
              ),
              TextButton(
                key: const Key('accounts-transfer-max'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.only(left: 8),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.merge(AccountTypography.caption),
                ),
                onPressed:
                    transfer.busy ||
                        frozen ||
                        account.stale ||
                        account.busy ||
                        balance?.availableBalance == null
                    ? null
                    : () => setState(() => amount.text = balance!.availableBalance.toString()),
                child: Text(l.accountsMax),
              ),
            ],
          ),
          if (account.account == null || account.stale)
            AccountAction(
              key: const Key('accounts-transfer-refresh'),
              label: l.accountRefreshWithWallet,
              primary: false,
              busy: account.busy,
              onPressed: ref.read(accountReadProvider.notifier).refresh,
            ),
          if (account.failure != null)
            Text(
              accountErrorText(context, account.failure!),
              style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
            ),
          if (destinations.isEmpty) AccountNotice(l.accountsNoDestination),
          if (frozen) AccountNotice(l.accountsFrozenNotice, warning: true),
        ],
        if (transfer.failure != null)
          Text(
            apiErrorText(context, transfer.failure!, transfer.details),
            style: AccountTypography.secondary.copyWith(color: PortfolioColors.negative),
          ),
      ],
    );
  }

  Future<String?> _choose(BuildContext context, Map<String, String> values, {String? source}) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => AccountTransferSelection(values: values, source: source),
        ),
      );
}

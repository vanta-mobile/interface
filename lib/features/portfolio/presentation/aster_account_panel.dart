import 'futures_history_screen.dart';
import 'position_margin_history.dart';
import '../../funding/presentation/internal_transfer_entry.dart';
import '../../funding/presentation/funding_info_screen.dart';
import '../../funding/domain/transfer_history.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/presentation/transfer_history_screen.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../../market/domain/market_precision.dart';
import '../application/account_read_provider.dart';
import '../domain/aster_account.dart';
import 'aster_account_rows.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';
import 'position_risk_screen.dart';
import 'account_change_panel.dart';
import 'account_event_status.dart';

class AsterAccountPanel extends ConsumerWidget {
  const AsterAccountPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final identity = session.identity;
    final state = ref.watch(accountReadProvider);
    final l10n = AppLocalizations.of(context);
    final address = identity?.walletAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.asterAccountTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(l10n.asterAccountScope, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('open-position-risk'),
          onPressed: () =>
              Navigator.of(context)
                  .push<void>(MaterialPageRoute(builder: (_) => const PositionRiskScreen())),
          icon: const Icon(Icons.shield_outlined),
          label: Text(l10n.positionRiskTitle),
        ),
        const AccountChangePanel(),
        const FuturesHistoryEntry(),
        const PositionMarginHistoryEntry(),
        const FundingInfoEntry(market: TransferMarket.perp),
        const InternalTransferEntry(),
        const TransferHistoryEntry(),
        const SizedBox(height: 16),
        if (address != null)
          Row(
            children: [
              Expanded(child: SelectableText(address, key: const Key('aster-account-address'))),
              IconButton(
                tooltip: tr(context, 'copyAddress'),
                onPressed: () => Clipboard.setData(ClipboardData(text: address)),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccountSummary(state: state),
              const SizedBox(height: 16),
              AccountReadControls(
                state: state,
                failureView: true,
                onRead: () => ref.read(accountReadProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
        if (state.account case final account?) ...[
          const SizedBox(height: 24),
          AccountEventStatus(time: account.lastEventAt),
          AsterAccountRows(account: account, accountStale: state.stale),
        ],
      ],
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.state});
  final AccountReadState state;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.asterUsdtSummary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ValueRow(l10n.asterMarginBalance, _amount(state.account?.marginBalance)),
        ValueRow(l10n.accountWalletBalance, _amount(state.account?.walletBalance)),
        ValueRow(tr(context, 'available'), _amount(state.account?.availableBalance)),
        ValueRow(tr(context, 'usedMargin'), _amount(state.account?.initialMargin)),
        ValueRow(l10n.accountUnrealizedPnl, _amount(state.account?.unrealizedProfit)),
        const SizedBox(height: 12),
        Text(l10n.asterUsdtScope, style: Theme.of(context).textTheme.bodySmall),
        AccountSnapshotStatus(state: state),
      ],
    );
  }

  String _amount(Decimal? value) => value == null ? '—' : '${marketNumber(value)} USDT';
}

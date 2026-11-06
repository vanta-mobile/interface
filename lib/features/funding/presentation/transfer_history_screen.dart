import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/transfer_history_provider.dart';
import '../domain/transfer_history.dart';
import 'transfer_record_details.dart';

void openTransferHistory(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TransferHistoryScreen()));

class TransferHistoryEntry extends ConsumerWidget {
  const TransferHistoryEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final needsRefresh = ref.watch(transferHistoryProvider.select((s) => s.stale));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsRefresh) Text(l10n.transferRefreshNeeded),
        OutlinedButton.icon(
          key: const Key('transfer-history-entry'),
          onPressed: () => openTransferHistory(context),
          icon: const Icon(Icons.swap_vert),
          label: Text(l10n.transferHistoryTitle),
        ),
      ],
    );
  }
}

class TransferHistoryScreen extends ConsumerStatefulWidget {
  const TransferHistoryScreen({super.key});
  @override
  ConsumerState<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends ConsumerState<TransferHistoryScreen> {
  TransferMarket? _market;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final state = ref.watch(transferHistoryProvider);
    final controller = ref.read(transferHistoryProvider.notifier);
    final address = auth.identity?.walletAddress;
    final canSign = address != null && auth.identity?.signingAvailable == true;
    final records = state.account?.records.where((r) => _market == null || r.market == _market);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferHistoryTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('transfer-history-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.transferHistoryScope),
            if (address != null) SelectableText(address),
            FilledButton(
              key: const Key('transfer-history-refresh'),
              onPressed: state.busy || auth.busy
                  ? null
                  : canSign
                  ? controller.refresh
                  : () => showAccountSheet(context),
              child: Text(canSign ? l10n.transferRefresh : l10n.accountSignInToRead),
            ),
            if (state.busy) ...[
              const LinearProgressIndicator(),
              Text(switch (state.step) {
                AccountReadStep.signing => l10n.accountReadSigning,
                AccountReadStep.loading => l10n.accountReadLoading,
                _ => l10n.accountReadPreparing,
              }),
              TextButton(
                key: const Key('transfer-history-stop'),
                onPressed: controller.stop,
                child: Text(l10n.historyStop),
              ),
            ],
            if (state.stale) Text(l10n.transferRefreshNeeded),
            if (state.failure case final failure?)
              Text(
                accountErrorText(context, failure),
                style: const TextStyle(color: AppColors.negative),
              ),
            if (state.initialBaseline) Text(l10n.transferBaselineCreated),
            if (state.account case final history?) ...[
              Text(l10n.transferReadTime(history.receivedAt.toIso8601String())),
              DropdownButtonFormField<TransferMarket?>(
                key: const Key('transfer-history-market'),
                initialValue: _market,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.transferMarketLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.transferAllMarkets)),
                  for (final market in TransferMarket.values)
                    DropdownMenuItem(value: market, child: Text(transferMarketLabel(l10n, market))),
                ],
                onChanged: (market) => setState(() => _market = market),
              ),
              if (records!.isEmpty) Text(l10n.transferHistoryEmpty),
              for (final record in records) _TransferCard(record),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard(this.record);
  final TransferRecord record;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ExpansionTile(
        key: ValueKey('transfer-${record.key}'),
        title: Text(transferTitle(l10n, record)),
        subtitle: Text(
          '${record.amount} ${record.asset} · ${transferMarketLabel(l10n, record.market)}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [TransferRecordDetails(record)],
      ),
    );
  }
}

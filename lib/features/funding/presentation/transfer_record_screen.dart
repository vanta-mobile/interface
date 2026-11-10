import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../application/transfer_history_provider.dart';
import '../domain/transfer_history.dart';
import 'transfer_history_components.dart';
import 'transfer_history_feedback.dart';
import 'transfer_record_details.dart';
import 'transfer_record_progress.dart';

class TransferRecordScreen extends ConsumerWidget {
  const TransferRecordScreen({
    super.key,
    required this.recordKey,
    required this.ownerAddress,
    this.initialRecord,
  });
  final TransferRecord? initialRecord;
  final String recordKey, ownerAddress;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(transferHistoryProvider);
    final currentOwner = ref.watch(authProvider).identity?.walletAddress;
    final sameOwner = currentOwner?.toLowerCase() == ownerAddress.toLowerCase();
    final latest = sameOwner && state.account?.address.toLowerCase() == ownerAddress.toLowerCase()
        ? state.account?.records.where((r) => r.key == recordKey).firstOrNull
        : null;
    final record = latest ?? (sameOwner && initialRecord?.key == recordKey ? initialRecord : null);
    final entry = ref.watch(activeAccountEntryProvider);
    final label = entry == null ? l.account : accountLabel(l, entry);
    return Scaffold(
      backgroundColor: PortfolioColors.background,
      body: SafeArea(
        child: Column(
          children: [
            HistoryHeader(title: l.assetHistoryDetails),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (sameOwner) await ref.read(transferHistoryProvider.notifier).refresh();
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal = constraints.maxWidth > 820
                        ? (constraints.maxWidth - 788) / 2
                        : 16.0;
                    return ListView(
                      key: const Key('transfer-record-details'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 32),
                      children: [
                        const TransferHistoryFeedback(),
                        if (record != null) ...[
                          PortfolioCard(
                            border: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  historyTypeLabel(l, record.type),
                                  style: AccountTypography.secondary,
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  historyAmount(record, signed: true),
                                  style: record.status == TransferStatus.success
                                      ? PortfolioTypography.metric
                                      : PortfolioTypography.heading,
                                ),
                                const SizedBox(height: 8),
                                HistoryStatus(record.status),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _Field(
                            l.account,
                            '$label · ${record.market == TransferMarket.perp ? l.assetHistoryFutures : l.spot}',
                          ),
                          _Field(l.transferNetwork, transferNetworkLabel(l, record.chainId)),
                          _Field(l.assetHistoryTime, historyTime(record.recordTime)),
                          _Field(
                            l.assetHistoryTransactionId,
                            record.txHash ?? l.assetHistoryUnavailable,
                          ),
                          const SizedBox(height: 4),
                          TransferRecordProgress(record),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: SizedBox(width: 100, child: Text(label, style: PortfolioTypography.caption)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: PortfolioTypography.caption.copyWith(color: PortfolioColors.text),
          ),
        ),
      ],
    ),
  );
}

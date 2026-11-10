import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_history_provider.dart';
import '../domain/futures_history.dart';
import 'account_snapshot_status.dart';
import 'futures_history_record_card.dart';
import '../../../core/presentation/status_view.dart';

class FuturesHistoryResults extends ConsumerWidget {
  const FuturesHistoryResults({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(futuresHistoryProvider);
    final session = ref.watch(authProvider);
    final controller = ref.read(futuresHistoryProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountSnapshotStatus(
          state: state,
          timeKey: const Key('futures-history-snapshot-time'),
          staleKey: const Key('futures-history-snapshot-stale'),
        ),
        if (state.account case final snapshot?) ...[
          const SizedBox(height: 16),
          Text(
            l10n.historyLoaded(snapshot.records.length),
            key: const Key('futures-history-record-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.pending.isNotEmpty
                ? l10n.historyPartial
                : state.truncated
                ? l10n.historyTruncated
                : l10n.historyComplete,
            key: const Key('futures-history-coverage'),
          ),
          if (state.truncated && state.pending.isNotEmpty) Text(l10n.historyTruncated),
          const SizedBox(height: 8),
          Text(l10n.historyNotAtomic, style: Theme.of(context).textTheme.bodySmall),
          if (snapshot.unitsUnavailable)
            Text(l10n.accountUnitUnavailable, style: Theme.of(context).textTheme.bodySmall),
          if (state.pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('continue-futures-history'),
              onPressed: state.busy || session.busy || session.identity?.signingAvailable != true
                  ? null
                  : controller.loadMore,
              child: Text(l10n.historyContinue),
            ),
          ],
          const SizedBox(height: 16),
          if (snapshot.records.isEmpty)
            StatusEmptyView(key: const Key('futures-history-empty'), message: l10n.historyEmpty)
          else
            FuturesHistoryRecords(snapshot: snapshot),
        ],
      ],
    );
  }
}

class FuturesHistoryRecords extends StatefulWidget {
  const FuturesHistoryRecords({super.key, required this.snapshot});
  final FuturesHistorySnapshot snapshot;
  @override
  State<FuturesHistoryRecords> createState() => _FuturesHistoryRecordsState();
}

class _FuturesHistoryRecordsState extends State<FuturesHistoryRecords> {
  static const perPage = 10;
  int page = 0;
  @override
  void didUpdateWidget(FuturesHistoryRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.query != widget.snapshot.query ||
        widget.snapshot.records.length < oldWidget.snapshot.records.length) {
      page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final records = widget.snapshot.records;
    final pages = (records.length + perPage - 1) ~/ perPage;
    final current = page < pages ? page : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.historyPage(current + 1, pages)),
            OutlinedButton(
              key: const Key('futures-history-previous'),
              onPressed: current == 0 ? null : () => setState(() => page = current - 1),
              child: Text(l10n.historyPrev),
            ),
            OutlinedButton(
              key: const Key('futures-history-next'),
              onPressed: current + 1 >= pages ? null : () => setState(() => page = current + 1),
              child: Text(l10n.historyNext),
            ),
          ],
        ),
        for (final record in records.skip(current * perPage).take(perPage))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FuturesHistoryRecordCard(key: ValueKey(record.key), record: record),
          ),
      ],
    );
  }
}

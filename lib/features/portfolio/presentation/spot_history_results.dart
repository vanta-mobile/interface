import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/spot_history_provider.dart';
import '../domain/spot_history.dart';
import 'account_snapshot_status.dart';
import 'spot_history_record_card.dart';

class SpotHistoryResults extends ConsumerWidget {
  const SpotHistoryResults({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotHistoryProvider);
    final session = ref.watch(authProvider);
    final controller = ref.read(spotHistoryProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountSnapshotStatus(
          state: state,
          timeKey: const Key('history-snapshot-time'),
          staleKey: const Key('history-snapshot-stale'),
        ),
        if (state.account case final snapshot?) ...[
          const SizedBox(height: 16),
          Text(
            l10n.historyLoaded(snapshot.records.length),
            key: const Key('history-record-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.pending.isNotEmpty
                ? l10n.historyPartial
                : state.truncated
                ? l10n.historyTruncated
                : l10n.historyComplete,
            key: const Key('history-coverage'),
          ),
          if (state.truncated && state.pending.isNotEmpty) Text(l10n.historyTruncated),
          const SizedBox(height: 8),
          Text(l10n.historyNotAtomic, style: Theme.of(context).textTheme.bodySmall),
          if (snapshot.unitsUnavailable)
            Text(l10n.accountUnitUnavailable, style: Theme.of(context).textTheme.bodySmall),
          if (state.pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('continue-spot-history'),
              onPressed: state.busy || session.busy || session.identity?.signingAvailable != true
                  ? null
                  : controller.loadMore,
              child: Text(l10n.historyContinue),
            ),
          ],
          const SizedBox(height: 16),
          if (snapshot.records.isEmpty)
            Text(l10n.historyEmpty, key: const Key('history-empty'))
          else
            SpotHistoryRecords(snapshot: snapshot),
        ],
      ],
    );
  }
}

class SpotHistoryRecords extends StatefulWidget {
  const SpotHistoryRecords({super.key, required this.snapshot});
  final SpotHistorySnapshot snapshot;
  @override
  State<SpotHistoryRecords> createState() => _SpotHistoryRecordsState();
}

class _SpotHistoryRecordsState extends State<SpotHistoryRecords> {
  static const perPage = 10;
  int page = 0;
  @override
  void didUpdateWidget(SpotHistoryRecords oldWidget) {
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
              key: const Key('history-previous'),
              onPressed: current == 0 ? null : () => setState(() => page = current - 1),
              child: Text(l10n.historyPrev),
            ),
            OutlinedButton(
              key: const Key('history-next'),
              onPressed: current + 1 >= pages ? null : () => setState(() => page = current + 1),
              child: Text(l10n.historyNext),
            ),
          ],
        ),
        for (final record in records.skip(current * perPage).take(perPage))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SpotHistoryRecordCard(key: ValueKey(record.key), record: record),
          ),
      ],
    );
  }
}

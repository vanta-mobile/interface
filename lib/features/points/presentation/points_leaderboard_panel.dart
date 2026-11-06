import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_status.dart';

class PointsLeaderboardPanel extends ConsumerStatefulWidget {
  const PointsLeaderboardPanel({super.key});
  @override
  ConsumerState<PointsLeaderboardPanel> createState() => _PointsLeaderboardPanelState();
}

class _PointsLeaderboardPanelState extends ConsumerState<PointsLeaderboardPanel> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final campaign = ref.watch(selectedPointsCampaignProvider);
    final state = ref.watch(pointsLeaderboardProvider(campaign));
    final controller = ref.read(pointsLeaderboardProvider(campaign).notifier);
    final rows = state.snapshot?.value.rows ?? const <PointsRanking>[];
    final pages = ((rows.length + 19) ~/ 20).clamp(1, 5), currentPage = page.clamp(0, pages - 1);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pointsLeaderboard, style: Theme.of(context).textTheme.titleLarge),
          Text(l10n.pointsLeaderboardScope),
          const SizedBox(height: 12),
          _LeaderboardSelection(
            campaign: campaign,
            onChanged: (value) {
              setState(() {
                ref.read(selectedPointsCampaignProvider.notifier).select(value == 0 ? null : value);
                page = 0;
              });
            },
          ),
          if (state.snapshot != null && rows.isEmpty) Text(l10n.pointsNoRankings),
          if (state.snapshot != null) Text(l10n.pointsReturnedCount(rows.length)),
          for (final row in rows.skip(currentPage * 20).take(20)) _RankingRow(row: row),
          if (pages > 1)
            _RankingPagination(
              page: currentPage,
              pages: pages,
              onPage: (value) => setState(() => page = value),
            ),
          PointsStatus(
            state: state,
            onRefresh: controller.refresh,
            onStop: controller.stop,
            sectionKey: 'board',
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSelection extends ConsumerWidget {
  const _LeaderboardSelection({required this.campaign, required this.onChanged});
  final int? campaign;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), cycles = ref.watch(pointsCampaignsProvider);
    final options = cycles.snapshot?.value ?? const <PointsCampaign>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('points-board-select-$campaign'),
          initialValue: campaign ?? 0,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(labelText: l10n.pointsSelectLeaderboard),
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.pointsTotalLeaderboard)),
            for (final cycle in options)
              DropdownMenuItem(
                value: cycle.number,
                child: Text(
                  pointsCampaignName(cycle, l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (campaign != null && !options.any((c) => c.number == campaign))
              DropdownMenuItem(value: campaign, child: Text(l10n.pointsCycleNumber('$campaign'))),
          ],
          onChanged: onChanged,
        ),
        PointsStatus(
          state: cycles,
          onRefresh: ref.read(pointsCampaignsProvider.notifier).refresh,
          onStop: ref.read(pointsCampaignsProvider.notifier).stop,
          sectionKey: 'cycles',
        ),
      ],
    );
  }
}

class _RankingPagination extends StatelessWidget {
  const _RankingPagination({required this.page, required this.pages, required this.onPage});
  final int page, pages;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        OutlinedButton(
          key: const Key('points-board-previous'),
          onPressed: page == 0 ? null : () => onPage(page - 1),
          child: Text(l10n.pointsPrevious),
        ),
        Text(l10n.pointsPageNumber(page + 1, pages)),
        OutlinedButton(
          key: const Key('points-board-next'),
          onPressed: page >= pages - 1 ? null : () => onPage(page + 1),
          child: Text(l10n.pointsNext),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.row});
  final PointsRanking row;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.pointsRankNumber('${row.rank}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(row.address),
          ValueRow(l10n.pointsScore, marketNumber(row.points)),
          if (row.settled != null) ValueRow(l10n.pointsSettled, marketNumber(row.settled!)),
          if (row.special != null) ValueRow(l10n.pointsSpecial, marketNumber(row.special!)),
          if (row.current != null) ValueRow(l10n.pointsCurrentScore, marketNumber(row.current!)),
        ],
      ),
    );
  }
}

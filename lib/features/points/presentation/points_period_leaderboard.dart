import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_labels.dart';
import 'points_leaderboard_widgets.dart';

/// Ranking for the period chosen in "Points by period".
class PointsPeriodLeaderboard extends ConsumerWidget {
  const PointsPeriodLeaderboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(pointsPeriodProvider);
    if (period == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(pointsLeaderboardProvider(period));
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final wallet = address != null && isPointsEvmAddress(address) ? address : null;
    final rank = wallet == null ? null : state.snapshot?.value.rankFor(wallet);
    final campaigns = ref.watch(pointsCampaignsProvider).snapshot?.value;
    final current = ref.watch(currentPointsCampaignProvider).snapshot?.value;
    final campaign = current?.number == period
        ? current
        : campaigns?.where((c) => c.number == period).firstOrNull;
    return Column(
      key: const Key('points-period-board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 26),
          child: Row(
            children: [
              Expanded(child: Text(l10n.pointsPeriodLeaderboard, style: PointsTypography.section)),
              if (rank != null)
                PointsRankBadge(
                  key: const Key('points-period-rank'),
                  label: l10n.pointsYourRank,
                  value: '#$rank',
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(pointsPeriodLabel(campaign, period, l10n), style: PointsTypography.scope),
        const SizedBox(height: 12),
        PointsSectionState<PointsLeaderboard>(
          state: state,
          retryKey: const Key('points-refresh-board'),
          onRetry: ref.read(pointsLeaderboardProvider(period).notifier).refresh,
          loading: PointsLeaderboardSkeleton(valueHeading: l10n.pointsUnit),
          data: (board) => board.rows.isEmpty
              ? const PointsLeaderboardEmpty()
              : PointsLeaderboardTable(
                  // A new period starts again from the first page.
                  key: ValueKey('points-board-$period'),
                  rows: board.rows,
                  address: wallet,
                  valueHeading: l10n.pointsUnit,
                  points: (row) => pointsValue(row.points),
                ),
        ),
      ],
    );
  }
}

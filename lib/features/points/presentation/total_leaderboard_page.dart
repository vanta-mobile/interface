import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_labels.dart';
import 'points_leaderboard_widgets.dart';

/// Cumulative ranking opened from the summary card.
class TotalLeaderboardPage extends ConsumerWidget {
  const TotalLeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(pointsLeaderboardProvider(null));
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final wallet = address != null && isPointsEvmAddress(address) ? address : null;
    return Scaffold(
      key: const Key('points-total-page'),
      backgroundColor: PointsColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: OverflowBox(
                        maxWidth: 44,
                        maxHeight: 44,
                        child: IconButton(
                          key: const Key('points-total-back'),
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: SizedBox.square(
                            dimension: 24,
                            child: Center(child: SvgPicture.asset('assets/points/back.svg')),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.pointsTotalLeaderboardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PointsTypography.heading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.watch(pointsTotalRefreshProvider),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    19,
                    16,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: PointsSectionState<PointsLeaderboard>(
                    state: state,
                    retryKey: const Key('points-refresh-total'),
                    onRetry: ref.read(pointsLeaderboardProvider(null).notifier).refresh,
                    loading: PointsLeaderboardSkeleton(valueHeading: l10n.pointsTotalCurrent),
                    data: (board) => board.rows.isEmpty
                        ? const PointsLeaderboardEmpty()
                        : PointsLeaderboardTable(
                            rows: board.rows,
                            address: wallet,
                            valueHeading: l10n.pointsTotalCurrent,
                            points: (row) => pointsValue(row.points),
                            secondary: (row) => l10n.pointsCurrentValue(
                              row.current == null ? '—' : pointsValue(row.current!),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

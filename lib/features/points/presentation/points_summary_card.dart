import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_labels.dart';
import 'points_leaderboard_widgets.dart';
import 'points_status.dart';
import 'total_leaderboard_page.dart';

/// Cumulative points and total rank; independent of the selected period.
class PointsSummaryCard extends ConsumerWidget {
  const PointsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final signedIn = address != null && isPointsEvmAddress(address);
    final wallet = ref.watch(walletPointsProvider);
    final board = ref.watch(pointsLeaderboardProvider(null));
    final total = wallet.snapshot?.value.total;
    return Container(
      key: const Key('points-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          // CSS 147.57° from the design.
          begin: Alignment(-0.536, -0.844),
          end: Alignment(0.536, 0.844),
          colors: [PointsColors.summaryStart, PointsColors.summaryEnd],
          stops: [0, 0.714],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.pointsMyTotal, style: PointsTypography.summaryLabel)),
              if (signedIn) _RefreshButton(loading: wallet.loading || board.loading),
            ],
          ),
          const SizedBox(height: 8),
          if (signedIn && total == null && wallet.failureKey == null)
            const SkeletonBox(
              key: Key('points-total-loading'),
              width: 120,
              height: 40,
              color: PointsColors.loadingValue,
            )
          else
            AnimatedNumberText(
              key: const Key('points-total'),
              total == null ? '—' : pointsValue(total),
              style: PointsTypography.total,
            ),
          const SizedBox(height: 8),
          if (signedIn)
            PointsRankBadge(
              key: const Key('points-total-rank'),
              label: l10n.pointsTotalRank,
              value: _rank(l10n, address, board.snapshot?.value),
            )
          else
            InkWell(
              key: const Key('points-login'),
              onTap: () => showAccountSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: PointsRankBadge(label: l10n.pointsTotalRank, value: l10n.pointsLoginHint),
            ),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('points-view-total'),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const TotalLeaderboardPage())),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.pointsViewTotalLeaderboard, style: PointsTypography.label),
                  ),
                  SvgPicture.asset('assets/points/chevron-right.svg', width: 16, height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The service returns at most 100 rows, so absence from a full board only
  /// means the wallet is outside the top 100, not that it has no rank.
  static String _rank(AppLocalizations l10n, String address, PointsLeaderboard? board) {
    if (board == null) return '—';
    final rank = board.rankFor(address);
    if (rank != null) return '#$rank';
    return board.rows.length >= 100 ? l10n.pointsOutsideTop : l10n.pointsNotRanked;
  }
}

class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton({required this.loading});
  final bool loading;

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_RefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.loading && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.loading && _spin.isAnimating) {
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(pointsSummaryRefreshProvider)();
    if (!mounted) return;
    final state = ref.read(walletPointsProvider);
    if (state.failureKey case final key?) {
      AppToast.showFailure(
        context,
        pointsFailureText(context, key, state.errorDetails),
        persistent: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 16,
      height: 18,
      child: OverflowBox(
        maxWidth: 44,
        maxHeight: 44,
        child: IconButton(
          key: const Key('points-refresh-summary'),
          tooltip: l10n.pointsRefreshMine,
          onPressed: widget.loading ? null : _refresh,
          padding: EdgeInsets.zero,
          icon: RotationTransition(
            turns: _spin,
            child: SvgPicture.asset('assets/points/refresh.svg', width: 16, height: 16),
          ),
        ),
      ),
    );
  }
}

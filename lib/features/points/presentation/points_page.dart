import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/presentation/app_toast.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/event_media_provider.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_period_leaderboard.dart';
import 'points_period_section.dart';
import 'points_status.dart';
import 'points_summary_card.dart';

final _pointsRules = Uri.https('app.vanta.exchange', '/docs/core-concepts/know-vanta');

class PointsPage extends ConsumerWidget {
  const PointsPage({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    await ref.read(pointsPageRefreshProvider)();
    if (!context.mounted) return;
    // Sections keep their data; report a failed refresh of data already shown.
    final period = ref.read(pointsPeriodProvider);
    final states = <PointsLoadState<Object?>>[
      ref.read(walletPointsProvider),
      ref.read(pointsCampaignsProvider),
      ref.read(pointsLeaderboardProvider(null)),
      if (period != null) ref.read(pointsLeaderboardProvider(period)),
    ];
    for (final state in states) {
      if (state.snapshot != null && state.failureKey != null) {
        AppToast.showFailure(
          context,
          pointsFailureText(context, state.failureKey!, state.errorDetails),
          persistent: false,
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: PointsColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Image.asset('assets/branding/mark.webp', width: 22, height: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.points, style: PointsTypography.header)),
                  SizedBox(
                    width: 24,
                    height: 44,
                    child: OverflowBox(
                      maxWidth: 44,
                      child: IconButton(
                        key: const Key('points-rules'),
                        tooltip: l10n.pointsRules,
                        padding: EdgeInsets.zero,
                        onPressed: () => ref.read(eventLinkLauncherProvider)(_pointsRules),
                        icon: SizedBox.square(
                          dimension: 24,
                          child: Center(child: SvgPicture.asset('assets/points/info.svg')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              // Sections stay mounted while scrolled away so their readers
              // and the leaderboard page survive.
              child: SingleChildScrollView(
                key: const Key('points-page'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 19, 16, 24),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PointsSummaryCard(),
                    SizedBox(height: 24),
                    PointsPeriodSection(),
                    SizedBox(height: 24),
                    PointsPeriodLeaderboard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

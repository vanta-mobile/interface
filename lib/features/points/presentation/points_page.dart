import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/points_provider.dart';
import 'points_leaderboard_panel.dart';
import 'points_status.dart';
import 'wallet_points_panel.dart';
import 'trading_events_page.dart';

class PointsPage extends ConsumerWidget {
  const PointsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: ref.watch(pointsPageRefreshProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        key: const Key('points-page'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.pointsProgramTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.pointsProgramScope),
            OutlinedButton.icon(
              key: const Key('points-open-events'),
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const TradingEventsPage())),
              icon: const Icon(Icons.celebration_outlined),
              label: Text(l10n.eventsTitle),
            ),
            const SizedBox(height: 16),
            const _CurrentCampaign(),
            const SizedBox(height: 16),
            const WalletPointsPanel(),
            const SizedBox(height: 16),
            const PointsLeaderboardPanel(),
          ],
        ),
      ),
    );
  }
}

class _CurrentCampaign extends ConsumerWidget {
  const _CurrentCampaign();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(currentPointsCampaignProvider);
    final controller = ref.read(currentPointsCampaignProvider.notifier);
    final campaign = state.snapshot?.value;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pointsCurrentCampaign, style: Theme.of(context).textTheme.titleLarge),
          if (campaign != null) ...[
            Text(
              pointsCampaignName(campaign, l10n),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ValueRow(l10n.pointsCycleId, '${campaign.number}'),
            ValueRow(l10n.pointsStatus, pointsCampaignStatus(campaign.status, l10n)),
            ValueRow(l10n.pointsPool, marketNumber(campaign.pool)),
            ValueRow(l10n.pointsPeriodStart, campaign.start.toIso8601String()),
            ValueRow(l10n.pointsPeriodEnd, campaign.end.toIso8601String()),
            ValueRow(l10n.pointsBroker, campaign.broker),
            if (campaign.description.isNotEmpty) SelectableText(campaign.description),
          ] else if (state.snapshot != null)
            Text(l10n.pointsNoCurrentCampaign)
          else if (!state.loading)
            Text(l10n.pointsNotRead),
          PointsStatus(
            state: state,
            onRefresh: controller.refresh,
            onStop: controller.stop,
            sectionKey: 'current',
          ),
        ],
      ),
    );
  }
}

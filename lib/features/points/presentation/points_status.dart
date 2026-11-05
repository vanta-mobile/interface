import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/points.dart';

String pointsCampaignName(PointsCampaign campaign, AppLocalizations l10n) =>
    campaign.name.trim().isEmpty ? l10n.pointsCycleNumber('${campaign.number}') : campaign.name;
String pointsCampaignStatus(String status, AppLocalizations l10n) => switch (status) {
  'DRAFT' => l10n.pointsStatusDraft,
  'ACTIVE' => l10n.pointsStatusActive,
  'ENDED' => l10n.pointsStatusEnded,
  'SETTLED' => l10n.pointsStatusSettled,
  _ => l10n.pointsStatusUnknown,
};

class PointsStatus<T> extends StatelessWidget {
  const PointsStatus({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onStop,
    required this.sectionKey,
  });
  final PointsLoadState<T> state;
  final Future<void> Function() onRefresh;
  final VoidCallback onStop;
  final String sectionKey;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.snapshot case final snapshot?)
          Text(l10n.pointsReadTime(snapshot.receivedAt.toIso8601String())),
        if (state.loading) ...[const LinearProgressIndicator(), Text(l10n.pointsLoading)],
        if (!state.active) Text(l10n.pointsPaused),
        if (state.stale) Text(l10n.pointsStale, style: const TextStyle(color: AppColors.warning)),
        if (state.failureKey case final key?)
          Text(switch (key) {
            'pointsDataInvalid' => l10n.pointsDataInvalid,
            'pointsNetwork' => l10n.pointsNetwork,
            'pointsRateLimited' => l10n.pointsRateLimited,
            'pointsWalletRequired' => l10n.pointsWalletRequired,
            _ => l10n.pointsUnavailable,
          }, style: const TextStyle(color: AppColors.warning)),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: Key('points-refresh-$sectionKey'),
              onPressed: state.loading || !state.active ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.pointsRefresh),
            ),
            if (state.loading)
              TextButton(
                key: Key('points-stop-$sectionKey'),
                onPressed: onStop,
                child: Text(l10n.pointsStop),
              ),
          ],
        ),
      ],
    );
  }
}

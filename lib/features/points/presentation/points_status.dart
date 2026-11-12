import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';

import '../../../core/presentation/status_view.dart';
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

/// Prefer the service's safe message; otherwise the known points cause.
String pointsFailureText(BuildContext context, String key, ApiErrorDetails? details) {
  final l10n = AppLocalizations.of(context);
  return apiErrorText(
    context,
    key,
    details,
    fallbackText: switch (key) {
      'pointsDataInvalid' => l10n.pointsDataInvalid,
      'pointsNetwork' => l10n.pointsNetwork,
      'pointsRateLimited' => l10n.pointsRateLimited,
      'pointsWalletRequired' => l10n.pointsWalletRequired,
      _ => l10n.pointsUnavailable,
    },
  );
}

class PointsStatus<T> extends StatefulWidget {
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
  State<PointsStatus<T>> createState() => _PointsStatusState<T>();
}

class _PointsStatusState<T> extends State<PointsStatus<T>> {
  // A reload clears the failure while it runs; keep the failure state and
  // its spinning Retry in place until that reload settles.
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  String _failureText(BuildContext context, String key) =>
      pointsFailureText(context, key, widget.state.errorDetails);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final failureKey = state.failureKey;
    final failureView = state.snapshot == null && (failureKey != null || _retrying);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.snapshot case final snapshot?)
          Text(l10n.pointsReadTime(snapshot.receivedAt.toIso8601String())),
        if (state.loading && !failureView) ...[
          const LinearProgressIndicator(),
          Text(l10n.pointsLoading),
        ],
        if (!state.active) Text(l10n.pointsPaused),
        if (state.stale) Text(l10n.pointsStale, style: const TextStyle(color: AppColors.warning)),
        if (failureView)
          StatusFailureView(
            message: failureKey == null ? null : _failureText(context, failureKey),
            retryKey: Key('points-refresh-${widget.sectionKey}'),
            retrying: _retrying || state.loading || !state.active,
            onRetry: _retry,
          )
        else if (failureKey != null)
          Text(_failureText(context, failureKey), style: const TextStyle(color: AppColors.warning)),
        Wrap(
          spacing: 8,
          children: [
            if (!failureView)
              OutlinedButton.icon(
                key: Key('points-refresh-${widget.sectionKey}'),
                onPressed: state.loading || !state.active ? null : widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.pointsRefresh),
              ),
            if (state.loading)
              TextButton(
                key: Key('points-stop-${widget.sectionKey}'),
                onPressed: widget.onStop,
                child: Text(l10n.pointsStop),
              ),
          ],
        ),
      ],
    );
  }
}

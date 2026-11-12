import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/strings.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/auth_session.dart';
import '../application/portfolio_stats_provider.dart';
import '../domain/account_snapshot.dart';

/// Statistics failures keep the server's safe message, or the wallet's own
/// answer followed by how to sign again.
String portfolioStatsErrorText(BuildContext context, Object failure) => switch (failure) {
  AuthFailure() => '${authFailureText(context, failure)}\n${tr(context, vantaApiSignInRequired)}',
  AccountReadFailure() => accountErrorText(context, failure),
  VantaApiFailure() => apiErrorText(
    context,
    failure.requiresSignIn ? vantaApiSignInRequired : failure.key,
    failure.details,
  ),
  _ => tr(context, vantaApiRequestFailed),
};

/// Shared failure state for a statistics section that has no data: missing
/// configuration, no wallet signature yet, a pending signature or a failed read.
/// Retry asks the wallet again when needed and spins until the reads settle.
class PortfolioStatsBlocked extends ConsumerWidget {
  const PortfolioStatsBlocked(this.view, {super.key, this.calendarMonth});
  final PortfolioStatsView view;
  final DateTime? calendarMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), failure = view.failure;
    final block = view.block!;
    return StatusFailureView(
      key: ValueKey('portfolio-stats-${block.name}'),
      retryKey: const Key('portfolio-stats-retry'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      title: switch (block) {
        PortfolioStatsBlock.unavailable => l.vantaApiUnavailableTitle,
        PortfolioStatsBlock.signIn => l.vantaApiSignInTitle,
        PortfolioStatsBlock.signing => l.vantaApiSigningTitle,
        PortfolioStatsBlock.failed => null,
      },
      message: switch (block) {
        PortfolioStatsBlock.unavailable => l.vantaApiUnavailable,
        PortfolioStatsBlock.signing => l.vantaApiSigning,
        _ when failure != null => portfolioStatsErrorText(context, failure),
        _ => l.vantaApiSignIn,
      },
      retrying: block == PortfolioStatsBlock.signing,
      retryLabel: block == PortfolioStatsBlock.signIn || block == PortfolioStatsBlock.signing
          ? l.vantaApiSignInAction
          : null,
      onRetry: block == PortfolioStatsBlock.unavailable
          ? null
          : () => ref.read(portfolioStatsRefreshProvider)(calendarMonth: calendarMonth),
    );
  }
}

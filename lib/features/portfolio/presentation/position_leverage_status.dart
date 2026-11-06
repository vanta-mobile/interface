import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/position_leverage_provider.dart';
import '../domain/position_leverage.dart';

class PositionLeverageStatus extends ConsumerWidget {
  const PositionLeverageStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(positionLeverageProvider), l10n = AppLocalizations.of(context);
    final result = state.result, intent = state.intent;
    final failure = state.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(switch (state.step) {
            LeverageStep.signingContext || LeverageStep.signing => l10n.accountReadSigning,
            LeverageStep.loadingContext => l10n.accountReadLoading,
            LeverageStep.submitting => l10n.leverageSubmitting,
            LeverageStep.checkSigning => l10n.leverageCheckSigning,
            LeverageStep.checking => l10n.leverageChecking,
            _ => l10n.accountReadPreparing,
          }, key: const Key('leverage-progress')),
        ],
        if (intent != null) ...[
          SelectableText(intent.context.symbol),
          SelectableText(intent.context.address),
        ],
        if (result != null && intent != null) ...[
          Text(
            result.needsRecheck
                ? l10n.leverageOutcomeUnknown
                : result.observed == intent.target
                ? l10n.leverageVerified(result.observed!)
                : l10n.leverageObservedDifferent(result.observed!, intent.target),
            key: const Key('leverage-result'),
          ),
          if (result.checkedAt case final time?)
            Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time.toUtc())} UTC'),
          Text(l10n.leverageResultScope, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (failure != null)
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
            key: const Key('leverage-error'),
          ),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('leverage-recheck'),
            onPressed: state.busy || ref.watch(authProvider.select((s) => s.busy))
                ? null
                : () => ref.read(positionLeverageProvider.notifier).recheck(),
            child: Text(l10n.leverageRecheck),
          ),
      ],
    );
  }
}

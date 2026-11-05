import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_position_mode_provider.dart';
import '../domain/futures_position_mode.dart';

String positionModeLabel(AppLocalizations l10n, FuturesPositionMode mode) =>
    mode == FuturesPositionMode.oneWay ? l10n.positionModeOneWay : l10n.positionModeHedge;

class FuturesPositionModeStatus extends ConsumerWidget {
  const FuturesPositionModeStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(futuresPositionModeProvider), l10n = AppLocalizations.of(context);
    final result = state.result, intent = state.intent;
    final failure = state.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(switch (state.step) {
            PositionModeStep.signingContext || PositionModeStep.signing => l10n.accountReadSigning,
            PositionModeStep.loadingContext => l10n.accountReadLoading,
            PositionModeStep.submitting => l10n.positionModeSubmitting,
            PositionModeStep.checkSigning => l10n.positionModeCheckSigning,
            PositionModeStep.checking => l10n.positionModeChecking,
            _ => l10n.accountReadPreparing,
          }, key: const Key('position-mode-progress')),
        ],
        if (intent != null) ...[
          Text(l10n.positionModeAllSymbols),
          SelectableText(intent.context.address),
        ],
        if (result != null && intent != null) ...[
          Text(
            result.needsRecheck
                ? l10n.positionModeOutcomeUnknown
                : result.observed == intent.target
                ? l10n.positionModeVerified(positionModeLabel(l10n, result.observed!))
                : l10n.positionModeObservedDifferent(
                    positionModeLabel(l10n, result.observed!),
                    positionModeLabel(l10n, intent.target),
                  ),
            key: const Key('position-mode-result'),
          ),
          if (result.checkedAt case final time?)
            Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time.toUtc())} UTC'),
          Text(l10n.leverageResultScope, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (failure != null)
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : '\n${l10n.accountErrorCode(failure.code!)}'}',
            style: const TextStyle(color: AppColors.negative),
            key: const Key('position-mode-error'),
          ),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('position-mode-recheck'),
            onPressed: state.busy || ref.watch(authProvider.select((s) => s.busy))
                ? null
                : () => ref.read(futuresPositionModeProvider.notifier).recheck(),
            child: Text(l10n.leverageRecheck),
          ),
      ],
    );
  }
}

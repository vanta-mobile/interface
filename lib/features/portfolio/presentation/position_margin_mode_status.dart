import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/position_margin_mode_provider.dart';
import '../domain/position_margin_mode.dart';

String marginModeLabel(AppLocalizations l10n, PositionMarginMode mode) =>
    mode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode;

class PositionMarginModeStatus extends ConsumerWidget {
  const PositionMarginModeStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(positionMarginModeProvider), l10n = AppLocalizations.of(context);
    final result = state.result, intent = state.intent;
    final failure = state.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(switch (state.step) {
            MarginModeStep.signingContext || MarginModeStep.signing => l10n.accountReadSigning,
            MarginModeStep.loadingContext => l10n.accountReadLoading,
            MarginModeStep.submitting => l10n.marginModeSubmitting,
            MarginModeStep.checkSigning => l10n.marginModeCheckSigning,
            MarginModeStep.checking => l10n.marginModeChecking,
            _ => l10n.accountReadPreparing,
          }, key: const Key('margin-mode-progress')),
        ],
        if (intent != null) ...[
          SelectableText(intent.context.symbol),
          SelectableText(intent.context.address),
        ],
        if (result != null && intent != null) ...[
          Text(
            result.needsRecheck
                ? l10n.marginModeOutcomeUnknown
                : result.observed == intent.target
                ? l10n.marginModeVerified(marginModeLabel(l10n, result.observed!))
                : l10n.marginModeObservedDifferent(
                    marginModeLabel(l10n, result.observed!),
                    marginModeLabel(l10n, intent.target),
                  ),
            key: const Key('margin-mode-result'),
          ),
          if (result.checkedAt case final time?)
            Text('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time.toUtc())} UTC'),
          Text(l10n.leverageResultScope, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (failure != null)
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : '\n${l10n.accountErrorCode(failure.code!)}'}',
            style: const TextStyle(color: AppColors.negative),
            key: const Key('margin-mode-error'),
          ),
        if (state.needsRecheck)
          OutlinedButton(
            key: const Key('margin-mode-recheck'),
            onPressed: state.busy || ref.watch(authProvider.select((s) => s.busy))
                ? null
                : () => ref.read(positionMarginModeProvider.notifier).recheck(),
            child: Text(l10n.leverageRecheck),
          ),
      ],
    );
  }
}

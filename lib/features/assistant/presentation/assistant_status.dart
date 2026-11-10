import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import '../../../core/presentation/app_toast.dart';

Future<void> copyAssistantText(BuildContext context, String value) async {
  final l10n = AppLocalizations.of(context);
  try {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) AppToast.showSuccess(context, l10n.assistantCopied);
  } catch (_) {
    if (context.mounted) AppToast.showFailure(context, l10n.assistantCopyFailed);
  }
}

class AssistantStatus extends ConsumerWidget {
  const AssistantStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (failure, details, storage, ready, authenticated, busy, active, phase) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.failureKey,
          s.errorDetails,
          s.storageFailureKey,
          s.historyReady,
          s.authenticated,
          s.busy,
          s.active,
          s.phase,
        ),
      ),
    );
    final l10n = AppLocalizations.of(context), controller = ref.read(assistantProvider.notifier);
    final phaseKey = switch (phase) {
      AssistantPhase.preparing => 'assistantPreparing',
      AssistantPhase.signing => 'assistantSigning',
      AssistantPhase.restoring => 'assistantRestoring',
      AssistantPhase.loadingHistory => 'assistantLoadingHistory',
      AssistantPhase.readingUsage => 'assistantReadingUsage',
      AssistantPhase.clearing => 'assistantClearing',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phaseKey != null) Text(tr(context, phaseKey), semanticsLabel: tr(context, phaseKey)),
        if (failure != null) AssistantNotice(text: apiErrorText(context, failure, details)),
        if (storage != null) ...[
          AssistantNotice(text: tr(context, storage)),
          if (ready)
            OutlinedButton(
              key: const Key('assistant-retry-save'),
              onPressed: active && !busy ? controller.retrySave : null,
              child: Text(l10n.assistantRetrySave),
            ),
        ],
        if (authenticated && !ready && !busy) ...[
          Text(l10n.assistantHistoryBlocked),
          OutlinedButton(
            key: const Key('assistant-retry-history'),
            onPressed: active ? controller.retryHistory : null,
            child: Text(l10n.assistantRetryHistory),
          ),
        ],
      ],
    );
  }
}

class AssistantNotice extends StatelessWidget {
  const AssistantNotice({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(color: AppColors.warning)),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import 'assistant_widgets.dart';

class AssistantHeader extends ConsumerWidget {
  const AssistantHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (authenticated, remaining, limit, clearable, version, usageLoading) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.authenticated,
          s.remaining,
          s.quota?.limit ?? s.dailyLimit,
          s.active &&
              s.phase == AssistantPhase.idle &&
              // Damaged local history stays clearable as its recovery path.
              (!s.historyReady || s.messages.isNotEmpty || s.draft.isNotEmpty),
          s.scopeVersion,
          s.remaining == null &&
              (s.phase == AssistantPhase.loadingHistory || s.phase == AssistantPhase.readingUsage),
        ),
      ),
    );
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const AssistantIcon('avatar-small', size: 24),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assistantTitle,
                  style: AssistantTypography.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (authenticated && usageLoading)
                  const Padding(
                    key: Key('assistant-remaining-skeleton'),
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: SkeletonBox(width: 120, height: 12),
                  )
                else if (authenticated)
                  Text(
                    l10n.assistantRemainingToday(remaining?.toString() ?? '–', '$limit'),
                    key: const Key('assistant-remaining'),
                    style: AssistantTypography.quota,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (authenticated)
            TextButton(
              key: const Key('assistant-clear'),
              onPressed: clearable ? () => _confirmClear(context, ref, version) : null,
              style: TextButton.styleFrom(
                foregroundColor: AssistantColors.muted,
                disabledForegroundColor: AssistantColors.muted,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: AssistantTypography.clear,
              ),
              child: Text(l10n.assistantClearAction),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref, int version) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.assistantClear),
        content: SingleChildScrollView(child: Text(l10n.assistantClearConfirm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.assistantCancel),
          ),
          TextButton(
            key: const Key('assistant-dialog-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.assistantClearAction),
          ),
        ],
      ),
    );
    if (context.mounted && yes == true) {
      await ref.read(assistantProvider.notifier).clearHistory(version);
    }
  }
}

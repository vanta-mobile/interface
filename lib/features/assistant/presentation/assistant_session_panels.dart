import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';

class AssistantChallengePanel extends ConsumerWidget {
  const AssistantChallengePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (challenge, phase, active) = ref.watch(
      assistantProvider.select((s) => (s.challenge, s.phase, s.active)),
    );
    if (challenge == null || phase != AssistantPhase.review) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), controller = ref.read(assistantProvider.notifier);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.assistantReview, style: Theme.of(context).textTheme.titleMedium),
            Text(l10n.assistantReviewHint),
            const SizedBox(height: 12),
            SelectableText(challenge.message, key: const Key('assistant-challenge-message')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('assistant-confirm-sign'),
                  onPressed: active ? () => controller.confirm(challenge) : null,
                  child: Text(l10n.assistantSign),
                ),
                OutlinedButton(
                  key: const Key('assistant-cancel-sign'),
                  onPressed: controller.stop,
                  child: Text(l10n.assistantCancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantUsagePanel extends ConsumerWidget {
  const AssistantUsagePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (quota, stale, phase, active) = ref.watch(
      assistantProvider.select((s) => (s.quota, s.quotaStale, s.phase, s.active)),
    );
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.assistantUsage),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          quota == null
              ? l10n.assistantUsageUnknown
              : l10n.assistantUsageValues(
                  quota.day,
                  quota.used?.toString() ?? l10n.assistantUnknown,
                  quota.remaining?.toString() ?? l10n.assistantUnknown,
                ),
        ),
        if (quota != null && stale) Text(l10n.assistantQuotaStale),
        OutlinedButton(
          key: const Key('assistant-read-usage'),
          onPressed: active && phase == AssistantPhase.idle
              ? ref.read(assistantProvider.notifier).readUsage
              : null,
          child: Text(l10n.assistantReadUsage),
        ),
      ],
    );
  }
}

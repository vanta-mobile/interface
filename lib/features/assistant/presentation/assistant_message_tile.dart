import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import '../domain/assistant.dart';
import 'assistant_status.dart';

class AssistantMessageTile extends ConsumerWidget {
  const AssistantMessageTile({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      assistantProvider.select((s) => s.messages.where((m) => m.id == id).firstOrNull),
    );
    if (message == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context), user = message.role == AssistantRole.user;
    final deliveryKey = switch (message.delivery) {
      AssistantDelivery.streaming => 'assistantStreaming',
      AssistantDelivery.interrupted => 'assistantInterrupted',
      AssistantDelivery.truncated => 'assistantTruncated',
      AssistantDelivery.failed => 'assistantReplyFailed',
      AssistantDelivery.complete => null,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: user ? AppColors.raised : AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user ? l10n.assistantYou : l10n.assistantReply,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.assistantCopy,
                  onPressed: message.content.isEmpty
                      ? null
                      : () => copyAssistantText(context, message.content),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            if (user)
              SelectableText(message.content)
            else if (message.content.isNotEmpty)
              AssistantMarkdown(data: message.content),
            if (message.reasoning.isNotEmpty)
              ExpansionTile(
                key: ValueKey('assistant-explanation-$id'),
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.assistantExplanation),
                children: [AssistantMarkdown(data: message.reasoning)],
              ),
            if (deliveryKey != null) AssistantNotice(text: tr(context, deliveryKey)),
          ],
        ),
      ),
    );
  }
}

/// Native text only: no WebView, HTML execution or automatic image requests.
class AssistantMarkdown extends ConsumerWidget {
  const AssistantMarkdown({super.key, required this.data});
  final String data;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MarkdownBody(
    data: data,
    selectable: true,
    softLineBreak: true,
    fitContent: false,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      codeblockDecoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(8),
      ),
      tableBorder: TableBorder.all(color: AppColors.line),
      blockquoteDecoration: const BoxDecoration(color: AppColors.raised),
    ),
    onTapLink: (_, href, _) => ref.read(assistantProvider.notifier).openLink(href),
    sizedImageBuilder: (_) => Text(AppLocalizations.of(context).assistantRemoteImage),
  );
}

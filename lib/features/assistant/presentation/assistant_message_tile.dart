import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import '../domain/assistant.dart';
import 'assistant_widgets.dart';

String assistantTime(DateTime value) => DateFormat('HH:mm').format(value.toLocal());

class AssistantMessageTile extends ConsumerWidget {
  const AssistantMessageTile({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      assistantProvider.select((s) => s.messages.where((m) => m.id == id).firstOrNull),
    );
    if (message == null) return const SizedBox.shrink();
    final user = message.role == AssistantRole.user;
    final empty = message.content.trim().isEmpty;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (user)
          _UserBubble(text: message.content)
        else if (message.delivery == AssistantDelivery.streaming && empty)
          const AssistantThinking()
        else ...[
          if (!empty || message.delivery == AssistantDelivery.interrupted)
            _ReplyBubble(message: message),
          if (message.delivery == AssistantDelivery.failed) ...[
            if (!empty) const SizedBox(height: 8),
            AssistantFailureCard(replyId: message.id),
          ],
        ],
        const SizedBox(height: 4),
        Text(
          assistantTime(message.createdAt),
          style: AssistantTypography.time,
          semanticsLabel: user ? null : l10n.assistantTitle,
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      constraints: BoxConstraints(maxWidth: (constraints.maxWidth * 0.84).clamp(0, 302)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AssistantColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(text, style: AssistantTypography.body),
    ),
  );
}

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.message});
  final AssistantMessage message;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final empty = message.content.trim().isEmpty;
    final note = switch (message.delivery) {
      AssistantDelivery.interrupted => l10n.assistantManuallyInterrupted,
      AssistantDelivery.truncated => l10n.assistantTruncated,
      _ => null,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AssistantColors.reply,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!empty) AssistantMarkdown(data: message.content),
          if (note != null && empty)
            Text(note, style: AssistantTypography.body)
          else if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: AssistantTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// Waiting for the first content of a reply.
class AssistantThinking extends StatefulWidget {
  const AssistantThinking({super.key});
  @override
  State<AssistantThinking> createState() => _AssistantThinkingState();
}

class _AssistantThinkingState extends State<AssistantThinking> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('assistant-thinking'),
    mainAxisSize: MainAxisSize.min,
    children: [
      RotationTransition(turns: _spin, child: const AssistantIcon('spinner', size: 16)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          AppLocalizations.of(context).assistantThinking,
          style: AssistantTypography.caption,
        ),
      ),
    ],
  );
}

// The website hides these service diagnostics behind its generic failure copy.
final _internalFailure = RegExp(
  r'starchild|upstream|edge_function|ai quota|supabase|api_key|env config',
  caseSensitive: false,
);

class AssistantFailureCard extends ConsumerWidget {
  const AssistantFailureCard({super.key, required this.replyId});
  final String replyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (latest, failure, details, canRetry) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.messages.lastOrNull?.id == replyId,
          s.failureKey,
          s.errorDetails,
          s.active && s.authenticated && s.phase == AssistantPhase.idle && !s.limitReached,
        ),
      ),
    );
    final l10n = AppLocalizations.of(context);
    final fallback = l10n.assistantResponseFailedBody;
    final internal = _internalFailure.hasMatch(details?.message ?? '');
    final body = !latest || failure == null
        ? fallback
        : apiErrorText(context, failure, internal ? null : details, fallbackText: fallback);
    return Container(
      key: ValueKey('assistant-failure-$replyId'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AssistantColors.failureSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/feedback/fail.svg', width: 20, height: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.assistantResponseFailedTitle, style: AssistantTypography.label),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: AssistantTypography.caption),
          if (latest) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('assistant-retry'),
              onPressed: canRetry
                  ? () => ref.read(assistantProvider.notifier).retry(replyId)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AssistantColors.error,
                disabledForegroundColor: AssistantColors.error.withValues(alpha: 0.4),
                side: const BorderSide(color: AssistantColors.line),
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: AssistantTypography.button,
              ),
              child: Text(l10n.assistantRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class AssistantLimitCard extends StatelessWidget {
  const AssistantLimitCard({super.key, required this.time});
  final DateTime? time;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('assistant-limit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AssistantColors.limitSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AssistantIcon('warn'),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.assistantLimitTitle, style: AssistantTypography.label)),
                ],
              ),
              const SizedBox(height: 10),
              Text(l10n.assistantLimitBody, style: AssistantTypography.caption),
            ],
          ),
        ),
        if (time != null) ...[
          const SizedBox(height: 4),
          Text(assistantTime(time!), style: AssistantTypography.time),
        ],
      ],
    );
  }
}

/// Native text only: no WebView, HTML execution or automatic image requests.
class AssistantMarkdown extends ConsumerWidget {
  const AssistantMarkdown({super.key, required this.data});
  final String data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const body = AssistantTypography.body;
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      fitContent: false,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        tableBody: body,
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        h1: body.copyWith(fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w700),
        h2: body.copyWith(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w700),
        h3: body.copyWith(fontWeight: FontWeight.w700),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        a: const TextStyle(color: AssistantColors.accent),
        code: body.copyWith(fontSize: 13, backgroundColor: AssistantColors.card),
        codeblockDecoration: BoxDecoration(
          color: AssistantColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBorder: TableBorder.all(color: AssistantColors.line),
        blockquoteDecoration: const BoxDecoration(color: AssistantColors.card),
      ),
      onTapLink: (_, href, _) => ref.read(assistantProvider.notifier).openLink(href),
      sizedImageBuilder: (_) => Text(
        AppLocalizations.of(context).assistantRemoteImage,
        style: AssistantTypography.caption,
      ),
    );
  }
}

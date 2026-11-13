import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import '../domain/assistant.dart';
import 'assistant_auth_prompt.dart';
import 'assistant_composer.dart';
import 'assistant_header.dart';
import 'assistant_message_tile.dart';
import 'assistant_skeleton.dart';
import 'assistant_widgets.dart';

/// Vanta AI primary destination, above the app navigation. A wallet with a stored AI session opens
/// straight into the conversation; otherwise it asks for wallet authentication.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_open);
  }

  void _open() {
    if (mounted) ref.read(assistantProvider.notifier).open();
  }

  @override
  Widget build(BuildContext context) {
    // The controller resets on an identity change; look for that wallet's session.
    ref.listen(assistantProvider.select((s) => s.sessionChecked), (_, checked) {
      if (!checked) scheduleMicrotask(_open);
    });
    ref.listen(assistantProvider.select((s) => (s.failureKey, s.errorDetails)), (_, next) {
      final (key, details) = next;
      final state = ref.read(assistantProvider);
      // Reply failures and expiry have their own in-page states.
      if (key == null ||
          !state.authenticated ||
          state.messages.lastOrNull?.delivery == AssistantDelivery.failed) {
        return;
      }
      AppToast.showFailure(context, apiErrorText(context, key, details));
    });
    final (authenticated, loading) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.authenticated,
          // Looking for or restoring a saved session, or its first history read.
          (!s.authenticated &&
                  (!s.sessionChecked ||
                      s.phase == AssistantPhase.restoring ||
                      s.phase == AssistantPhase.loadingHistory ||
                      s.phase == AssistantPhase.readingUsage)) ||
              (s.phase == AssistantPhase.loadingHistory && s.messages.isEmpty),
        ),
      ),
    );
    return ColoredBox(
      color: AssistantColors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = constraints.maxWidth > 820 ? (constraints.maxWidth - 788) / 2 : 0.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Column(
                key: const Key('assistant-page'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 7),
                  const AssistantHeader(),
                  Expanded(
                    child: loading
                        ? const AssistantSkeleton()
                        : authenticated
                        ? const _Conversation()
                        : const AssistantAuthPrompt(),
                  ),
                  if (authenticated) ...[
                    AssistantComposer(pageHeight: constraints.maxHeight),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Stream updates only rebuild the message that consumes them; reading
/// history does not jump to the bottom.
class _Conversation extends ConsumerStatefulWidget {
  const _Conversation();
  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _scroll = ScrollController();
  bool _scrollScheduled = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow({bool force = false}) {
    if (_scrollScheduled || !_scroll.hasClients || (!force && _scroll.position.extentAfter > 120)) {
      return;
    }
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(assistantProvider.select((s) => s.messages.map((m) => m.id).join('\n')));
    final (limitReached, limitTime) = ref.watch(
      assistantProvider.select(
        (s) => (s.limitReached, s.limitReachedAt ?? (s.limitReached ? s.quotaReadAt : null)),
      ),
    );
    ref.listen(
      assistantProvider.select((s) => s.messages.isEmpty ? null : s.messages.last),
      (previous, next) => _follow(force: previous?.id != next?.id),
    );
    ref.listen(assistantProvider.select((s) => s.limitReached), (_, _) => _follow(force: true));
    final messageIds = ids.isEmpty ? <String>[] : ids.split('\n');
    final controller = ref.read(assistantProvider.notifier);
    return RefreshIndicator(
      color: AssistantColors.accent,
      backgroundColor: AssistantColors.card,
      // Re-reads today's usage, the only server data on this page.
      onRefresh: controller.readUsage,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, messageIds.isEmpty ? 24 : 16, 16, 24),
        children: [
          const _StorageNotice(),
          if (messageIds.isEmpty)
            const _Welcome()
          else
            for (final (index, id) in messageIds.indexed) ...[
              if (index > 0) const SizedBox(height: 16),
              AssistantMessageTile(key: ValueKey(id), id: id),
            ],
          if (limitReached) ...[const SizedBox(height: 16), AssistantLimitCard(time: limitTime)],
        ],
      ),
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      assistantProvider.select(
        (s) =>
            s.active &&
            s.authenticated &&
            s.historyReady &&
            s.phase == AssistantPhase.idle &&
            !s.limitReached,
      ),
    );
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(assistantProvider.notifier);
    return Column(
      key: const Key('assistant-welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AssistantIcon('avatar-large', size: 48),
        const SizedBox(height: 24),
        Text(l10n.assistantCopilotTitle, style: AssistantTypography.title),
        const SizedBox(height: 24),
        Text(l10n.assistantCopilotIntro, style: AssistantTypography.secondary),
        const SizedBox(height: 24),
        for (final (index, (icon, prompt)) in [
          ('prompt-chart', l10n.assistantPromptMarket),
          ('prompt-wallet', l10n.assistantPromptFunding),
          ('prompt-candle', l10n.assistantPromptGuide),
        ].indexed) ...[
          if (index > 0) const SizedBox(height: 10),
          Material(
            color: AssistantColors.card,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: ValueKey('assistant-suggestion-$index'),
              onTap: enabled ? () => controller.send(prompt: prompt) : null,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      AssistantIcon(icon),
                      const SizedBox(width: 12),
                      Expanded(child: Text(prompt, style: AssistantTypography.body)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Local history that cannot be read or saved stays recoverable in place.
class _StorageNotice extends ConsumerWidget {
  const _StorageNotice();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (storage, ready, busy, active) = ref.watch(
      assistantProvider.select((s) => (s.storageFailureKey, s.historyReady, s.busy, s.active)),
    );
    final l10n = AppLocalizations.of(context), controller = ref.read(assistantProvider.notifier);
    final (text, label, key, action) = !ready && !busy
        ? (
            l10n.assistantHistoryBlocked,
            l10n.assistantRetryHistory,
            'assistant-retry-history',
            controller.retryHistory,
          )
        : storage != null
        ? (
            tr(context, storage),
            l10n.assistantRetrySave,
            'assistant-retry-save',
            controller.retrySave,
          )
        : (null, null, null, null);
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AssistantTypography.caption.copyWith(color: AssistantColors.error)),
          TextButton(
            key: Key(key!),
            onPressed: active && !busy ? action : null,
            style: TextButton.styleFrom(
              foregroundColor: AssistantColors.accent,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              textStyle: AssistantTypography.button,
            ),
            child: Text(label!),
          ),
        ],
      ),
    );
  }
}

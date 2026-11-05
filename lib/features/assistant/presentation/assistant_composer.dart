import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';

class AssistantComposer extends ConsumerStatefulWidget {
  const AssistantComposer({super.key});
  @override
  ConsumerState<AssistantComposer> createState() => _AssistantComposerState();
}

class _AssistantComposerState extends ConsumerState<AssistantComposer> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (draft, phase, active, authenticated, ready, canSend, version) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.draft,
          s.phase,
          s.active,
          s.authenticated,
          s.historyReady,
          s.canSend,
          s.scopeVersion,
        ),
      ),
    );
    if (_text.text != draft) {
      _text.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    final l10n = AppLocalizations.of(context), controller = ref.read(assistantProvider.notifier);
    final editable =
        active &&
        authenticated &&
        ready &&
        (phase == AssistantPhase.idle || phase == AssistantPhase.sending);
    final stoppable = phase != AssistantPhase.idle && phase != AssistantPhase.review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('assistant-input-$version'),
          controller: _text,
          enabled: editable,
          minLines: 2,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: controller.setDraft,
          decoration: InputDecoration(labelText: l10n.assistantPrompt),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.assistantCharacterCount(draft.length),
          style: TextStyle(color: draft.length > 12000 ? AppColors.warning : AppColors.secondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('assistant-send'),
              onPressed: canSend ? controller.send : null,
              icon: const Icon(Icons.arrow_upward),
              label: Text(l10n.assistantSend),
            ),
            if (stoppable)
              OutlinedButton(
                key: const Key('assistant-stop'),
                onPressed: controller.stop,
                child: Text(l10n.assistantStop),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.assistantInputHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(l10n.assistantLocalHistoryHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

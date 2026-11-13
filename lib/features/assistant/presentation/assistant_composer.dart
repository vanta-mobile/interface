import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/assistant_provider.dart';
import 'assistant_widgets.dart';

/// Message input with send/stop. Grows to five lines, then scrolls inside.
class AssistantComposer extends ConsumerStatefulWidget {
  const AssistantComposer({super.key, required this.pageHeight});

  /// Height of the whole page, so a short window keeps room for the conversation.
  final double pageHeight;
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
    final (draft, phase, editable, canSend, version) = ref.watch(
      assistantProvider.select(
        (s) => (
          s.draft,
          s.phase,
          s.active &&
              s.authenticated &&
              s.historyReady &&
              (s.phase == AssistantPhase.idle || s.phase == AssistantPhase.sending),
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
    final stoppable = phase == AssistantPhase.sending || phase == AssistantPhase.restoring;
    final button = _ActionButton(
      stop: stoppable,
      label: stoppable ? l10n.assistantStop : l10n.assistantSend,
      onPressed: stoppable ? controller.stop : (canSend ? controller.send : null),
    );
    final scale = MediaQuery.textScalerOf(context).scale(20) / 20;
    // Header, a minimum of conversation, and the composer's fixed parts.
    final spare = widget.pageHeight - 51 - 44 * scale - 80 - 98 - 26 * scale;
    final maxLines = (spare / (20 * scale)).floor().clamp(1, 5);
    final field = TextField(
      key: ValueKey('assistant-input-$version'),
      controller: _text,
      enabled: editable,
      minLines: 1,
      maxLines: maxLines,
      textInputAction: TextInputAction.newline,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: controller.setDraft,
      style: AssistantTypography.secondary,
      cursorColor: AssistantColors.accent,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: l10n.assistantPrompt,
        hintStyle: AssistantTypography.placeholder,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Text that no longer fits beside the button moves above it.
              final painter = TextPainter(
                text: TextSpan(text: draft, style: AssistantTypography.secondary),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout(maxWidth: (constraints.maxWidth - 62).clamp(0, double.infinity));
              final multiline = draft.contains('\n') || painter.didExceedMaxLines;
              painter.dispose();
              return Container(
                padding: EdgeInsets.fromLTRB(8, multiline ? 14 : 6, 8, 6),
                decoration: BoxDecoration(
                  color: AssistantColors.input,
                  border: Border.all(color: AssistantColors.inputBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: multiline
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerRight, child: button),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: field),
                          const SizedBox(width: 8),
                          button,
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 26),
            child: Center(
              child: Text(
                l10n.assistantDisclaimer,
                textAlign: TextAlign.center,
                style: AssistantTypography.disclaimer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.stop, required this.label, required this.onPressed});
  final bool stop;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Opacity(
      opacity: onPressed == null ? 0.3 : 1,
      child: Material(
        color: AssistantColors.accent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key(stop ? 'assistant-stop' : 'assistant-send'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(dimension: 36, child: AssistantIcon(stop ? 'stop' : 'send')),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme.dart';

/// Design SVG from `assets/assistant/`, centered in its design slot.
class AssistantIcon extends StatelessWidget {
  const AssistantIcon(this.name, {super.key, this.size = 20});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: SvgPicture.asset('assets/assistant/$name.svg', excludeFromSemantics: true),
    ),
  );
}

/// Full-width primary action; shows a spinner and ignores taps while busy.
class AssistantPrimaryButton extends StatelessWidget {
  const AssistantPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AssistantColors.accent,
      foregroundColor: AssistantColors.onAccent,
      disabledBackgroundColor: AssistantColors.accent.withValues(alpha: busy ? 1 : 0.3),
      disabledForegroundColor: AssistantColors.onAccent,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AssistantTypography.button,
    ),
    child: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AssistantColors.onAccent),
          )
        : Text(label, textAlign: TextAlign.center),
  );
}

/// Bordered information card used by the authentication states.
class AssistantInfoCard extends StatelessWidget {
  const AssistantInfoCard({super.key, required this.title, required this.body, this.gap = 12});
  final String title, body;
  final double gap;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AssistantColors.card,
      border: Border.all(color: AssistantColors.line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AssistantTypography.body),
        SizedBox(height: gap),
        Text(body, style: AssistantTypography.secondary),
      ],
    ),
  );
}

/// Back arrow with a 44-point touch target that reaches the screen edge.
class AssistantBackButton extends StatelessWidget {
  const AssistantBackButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      key: const Key('assistant-back'),
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 0, 10),
        child: AssistantIcon('back', size: 24),
      ),
    ),
  );
}

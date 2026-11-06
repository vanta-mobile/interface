import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// One editable value preserves native paste, backspace, selection and autofill.
/// The six cells are only a visual representation of that value.
class VerificationCodeInput extends StatefulWidget {
  const VerificationCodeInput({
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
    this.hasError = false,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool enabled, hasError;

  @override
  State<VerificationCodeInput> createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant VerificationCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text.padRight(6).split('').take(6).toList();
    final selected = widget.controller.selection.baseOffset.clamp(0, 5);
    final height = math.max(58.0, MediaQuery.textScalerOf(context).scale(26) + 24);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Row(
              spacing: 8,
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Container(
                    key: Key('code-cell-$index'),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.authInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.hasError
                            ? AppColors.authError
                            : _focus.hasFocus &&
                                  index == selected &&
                                  widget.controller.text.length < 6
                            ? AppColors.authAccent
                            : AppColors.authButton,
                      ),
                    ),
                    child: Text(digits[index].trim(), style: AuthTypography.heading),
                  ),
                ),
              ),
            ),
          ),
          TextField(
            key: const Key('login-code'),
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: widget.onSubmitted,
            enableInteractiveSelection: true,
            showCursor: false,
            style: const TextStyle(color: AppColors.transparent),
            cursorColor: AppColors.transparent,
            decoration: InputDecoration(
              semanticCounterText: AppLocalizations.of(context).verificationCode,
              hintText: '',
              label: Semantics(
                label: AppLocalizations.of(context).verificationCode,
                child: const SizedBox.shrink(),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              filled: false,
              fillColor: AppColors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: (height - 20) / 2),
            ),
          ),
        ],
      ),
    );
  }
}

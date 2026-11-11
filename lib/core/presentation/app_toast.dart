import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

enum AppToastType { success, failure }

/// Application-level status message shown at the top of the root overlay.
///
/// Success dismisses after [autoDismissDuration]. Failures default to manual
/// dismissal, and success feedback cannot replace a visible failure.
abstract final class AppToast {
  static const autoDismissDuration = Duration(seconds: 3);
  static OverlayEntry? _currentEntry;
  static AppToastType? _currentType;

  static void showSuccess(BuildContext context, String message) {
    if (_currentType == AppToastType.failure) return;
    _show(context, message, AppToastType.success, persistent: false);
  }

  static void showFailure(BuildContext context, String message, {bool persistent = true}) =>
      _show(context, message, AppToastType.failure, persistent: persistent);

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentType = null;
  }

  static void _show(
    BuildContext context,
    String message,
    AppToastType type, {
    required bool persistent,
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastMessage(
        message: message,
        type: type,
        persistent: persistent,
        onExpired: () {
          if (identical(_currentEntry, entry)) dismiss();
        },
      ),
    );
    _currentEntry = entry;
    _currentType = type;
    overlay.insert(entry);
  }
}

class _AppToastMessage extends StatefulWidget {
  const _AppToastMessage({
    required this.message,
    required this.type,
    required this.persistent,
    required this.onExpired,
  });

  final String message;
  final AppToastType type;
  final bool persistent;
  final VoidCallback onExpired;

  @override
  State<_AppToastMessage> createState() => _AppToastMessageState();
}

class _AppToastMessageState extends State<_AppToastMessage> {
  // Replacing or closing the toast disposes this state and cancels the timer.
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.persistent) {
      _dismissTimer = Timer(AppToast.autoDismissDuration, widget.onExpired);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final success = widget.type == AppToastType.success;
    return Positioned(
      top: padding.top + 8,
      left: padding.left + 16,
      right: padding.right + 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 313),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Material(
              key: const Key('app-toast'),
              type: MaterialType.transparency,
              child: Container(
                // Container adds the border width to the padding, matching
                // the design's 46px bordered and 44px borderless heights.
                padding: EdgeInsets.only(left: 16, right: widget.persistent ? 4 : 16),
                decoration: BoxDecoration(
                  color: ToastColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: success ? Border.all(color: ToastColors.border) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              success ? 'assets/feedback/success.svg' : 'assets/feedback/fail.svg',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(widget.message, style: ToastTypography.message)),
                          ],
                        ),
                      ),
                    ),
                    if (widget.persistent) const _AppToastCloseButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppToastCloseButton extends StatelessWidget {
  const _AppToastCloseButton();

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('app-toast-close'),
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    onPressed: AppToast.dismiss,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    icon: SvgPicture.asset(
      'assets/feedback/close.svg',
      width: 16,
      height: 16,
      colorFilter: const ColorFilter.mode(ToastColors.icon, BlendMode.srcIn),
    ),
  );
}

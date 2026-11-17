import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

enum AppToastType { success, failure }

/// Application-level status message shown at the top of the root overlay.
///
/// Success dismisses after [autoDismissDuration]. Failures default to manual
/// dismissal. A user action's success replaces a visible failure; background
/// notices pass [showSuccess]'s `preserveFailure` so they cannot hide one.
abstract final class AppToast {
  static const autoDismissDuration = Duration(seconds: 3);
  static OverlayEntry? _currentEntry;
  static AppToastType? _currentType;

  static void showSuccess(BuildContext context, String message, {bool preserveFailure = false}) {
    if (preserveFailure && _currentType == AppToastType.failure) return;
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

class _AppToastMessageState extends State<_AppToastMessage> with SingleTickerProviderStateMixin {
  // Replacing or closing the toast disposes this state, cancelling the timer.
  // The timer owns dismissal; the controller only draws the remaining time.
  Timer? _dismissTimer;
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: AppToast.autoDismissDuration,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.persistent) {
      _dismissTimer = Timer(AppToast.autoDismissDuration, widget.onExpired);
      _countdown.forward();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _countdown.dispose();
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
                padding: const EdgeInsets.only(left: 16, right: 4),
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
                    _AppToastCloseButton(countdown: widget.persistent ? null : _countdown),
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

/// Close action; an auto-dismissing toast rings it with the time remaining.
class _AppToastCloseButton extends StatelessWidget {
  const _AppToastCloseButton({this.countdown});
  final Animation<double>? countdown;

  @override
  Widget build(BuildContext context) {
    final button = _button(context);
    final countdown = this.countdown;
    if (countdown == null) return button;
    // Reduced motion keeps a static ring; the toast still closes on time.
    final remaining = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation(0.0)
        : countdown;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: remaining,
            builder: (context, _) => CustomPaint(
              key: const Key('app-toast-countdown'),
              size: const Size.square(24),
              painter: _CountdownRingPainter(1 - remaining.value),
            ),
          ),
        ),
        button,
      ],
    );
  }

  Widget _button(BuildContext context) => IconButton(
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

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0) return;
    final paint = Paint()
      ..color = ToastColors.icon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(paint.strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.fraction != fraction;
}

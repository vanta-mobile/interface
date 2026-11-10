import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme.dart';

/// Section-scoped load failure with an optional retry.
///
/// [onRetry] should resolve once the retried request settles; the button
/// stays disabled with a spinner until then. Failures surface through the
/// owning provider's state, so errors from [onRetry] are not rethrown here.
class StatusFailureView extends StatelessWidget {
  const StatusFailureView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retrying = false,
    this.retryKey = const Key('status-retry'),
    this.padding = StatusLayout.defaultPadding,
  });

  final String? title, message;
  final Future<void> Function()? onRetry;

  /// Keeps the retry spinner visible while an externally owned request runs.
  final bool retrying;
  final Key retryKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatusLayout(
      key: const Key('status-failure'),
      image: 'assets/feedback/load-failed.webp',
      title: title ?? l10n.statusLoadFailedTitle,
      message: message ?? l10n.statusLoadFailedMessage,
      padding: padding,
      actionKey: retryKey,
      actionLabel: l10n.statusRetry,
      actionLoading: retrying,
      onAction: onRetry,
    );
  }
}

/// Section-scoped empty state; defaults to the design's generic copy.
class StatusEmptyView extends StatelessWidget {
  const StatusEmptyView({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey = const Key('status-action'),
    this.padding = StatusLayout.defaultPadding,
  });

  final String? title, message, actionLabel;
  final FutureOr<void> Function()? onAction;
  final Key actionKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatusLayout(
      key: const Key('status-empty'),
      image: 'assets/feedback/empty.webp',
      title: title ?? l10n.statusEmptyTitle,
      message: message ?? l10n.statusEmptyMessage,
      padding: padding,
      actionKey: actionKey,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class StatusLayout extends StatelessWidget {
  const StatusLayout({
    super.key,
    required this.image,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
    this.actionKey,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.symmetric(vertical: 72);

  /// Below this width the copy spans the column and the action hugs its label.
  static const _textWidth = 240.0;

  final String image, title, message;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;
  final bool actionLoading;
  final Key? actionKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < _textWidth;
      return Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(image, width: 80, height: 80, excludeFromSemantics: true),
            const SizedBox(height: 16),
            SizedBox(
              width: narrow ? double.infinity : _textWidth,
              child: Column(
                children: [
                  Text(title, textAlign: TextAlign.center, style: StatusTypography.title),
                  const SizedBox(height: 4),
                  Text(message, textAlign: TextAlign.center, style: StatusTypography.message),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              StatusActionButton(
                key: actionKey,
                label: actionLabel!,
                onPressed: onAction!,
                loading: actionLoading,
                narrow: narrow,
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Outlined state action that disables itself and spins while its future runs.
class StatusActionButton extends StatefulWidget {
  const StatusActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.narrow = false,
  });

  final String label;
  final FutureOr<void> Function() onPressed;
  final bool loading;

  /// Narrow columns hug the label instead of using the design's 120px width.
  final bool narrow;

  @override
  State<StatusActionButton> createState() => _StatusActionButtonState();
}

class _StatusActionButtonState extends State<StatusActionButton> {
  bool _pending = false;

  Future<void> _press() async {
    final result = widget.onPressed();
    if (result is! Future) return;
    setState(() => _pending = true);
    try {
      await result;
    } catch (_) {
      // The owning section renders the failure from its provider state.
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _pending || widget.loading;
    return Semantics(
      button: true,
      enabled: !loading,
      label: widget.label,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: loading ? null : _press,
        style: OutlinedButton.styleFrom(
          fixedSize: widget.narrow ? null : const Size(120, 40),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: StatusColors.title,
          disabledForegroundColor: StatusColors.title,
          side: const BorderSide(color: StatusColors.actionBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: StatusTypography.action,
        ),
        child: loading
            ? const SizedBox.square(
                key: Key('status-action-loading'),
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: StatusColors.title),
              )
            : Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Rounded placeholder bar from the design's loading skeleton component.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 4});
  final double? width;
  final double height, radius;

  const SkeletonBox.circle(double size, {super.key})
    : width = size,
      height = size,
      radius = size / 2;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: StatusColors.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import 'portfolio_components.dart';
import '../../../core/presentation/no_press_feedback.dart';

Future<T?> showModeSettingsSheet<T>(BuildContext context, Widget child) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: AppColors.authOverlay,
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, animation, secondaryAnimation) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      // The sheet rises above the keyboard and fits the height left, so a
      // focused field scrolls into the visible part of its content.
      Builder(
        builder: (context) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: true,
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: (MediaQuery.sizeOf(context).height - keyboard) * .92,
                  ),
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: Material(
                      color: TradeColors.sheet,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: TradeColors.card),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
    position: Tween(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
    child: FadeTransition(opacity: animation, child: child),
  ),
);

class ModeSheetBody extends StatelessWidget {
  const ModeSheetBody({super.key, required this.title, required this.children, this.onRefresh});
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TradeTypography.heading)),
              SizedBox(
                width: 24,
                height: 44,
                child: OverflowBox(
                  maxWidth: 44,
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                    padding: EdgeInsets.zero,
                    tooltip: AppLocalizations.of(context).close,
                    onPressed: () => Navigator.pop(context),
                    icon: const PortfolioIcon('close.svg', size: 24, color: TradeColors.text),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: TradeColors.line),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
    return onRefresh == null ? content : RefreshIndicator(onRefresh: onRefresh!, child: content);
  }
}

class ModeOptionCard extends StatelessWidget {
  const ModeOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    this.onTap,
    this.busy = false,
    this.loading = false,
    this.disabled = false,
  });
  final String title, description;
  final bool selected, busy;

  /// The current choice is not known yet: the check box is a skeleton.
  final bool loading;

  /// Not selectable for a known reason, shown dimmed.
  final bool disabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      selected: selected,
      enabled: !disabled,
      button: true,
      child: Opacity(
        opacity: disabled ? .4 : 1,
        child: Material(
          color: TradeColors.card,
          borderRadius: BorderRadius.circular(12),
          child: NoPressFeedback(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : loading
                          ? const SkeletonBox(
                              width: 20,
                              height: 20,
                              radius: 8,
                              color: StatusColors.skeletonOnCard,
                            )
                          : Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected ? TradeColors.accent : null,
                                border: selected ? null : Border.all(color: TradeColors.muted),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: selected
                                  ? const TradeIcon(
                                      'check',
                                      size: 12,
                                      color: TradeColors.background,
                                    )
                                  : null,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TradeTypography.symbol),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TradeTypography.body.copyWith(color: TradeColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ModeError extends StatelessWidget {
  const ModeError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: PortfolioColors.negativeSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: TradeTypography.body.copyWith(color: TradeColors.negative)),
  );
}

class ModeAction extends StatelessWidget {
  const ModeAction({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.large = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// The sheets' bottom Confirm: 48 px high with 16 px bold text.
  final bool large;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: TradeColors.accent,
      foregroundColor: TradeColors.background,
      disabledBackgroundColor: TradeColors.card,
      disabledForegroundColor: TradeColors.muted,
      minimumSize: Size(0, large ? 48 : 44),
      shape: large ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) : null,
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: large ? 16 : 13,
        height: large ? 24 / 16 : 18 / 13,
        fontWeight: FontWeight.w700,
      ),
    ).copyWith(overlayColor: PressFeedback.overlay),
    child: busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: label),
          )
        : Text(label),
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../trade_theme.dart';

/// Figma "Tooltip / Information" (331:80867): a tap-to-toggle bubble anchored
/// to [child]'s right edge, with its arrow 18 px from that edge. Opens above
/// the target, or below (arrow flipped) when there is no room; tapping
/// anywhere closes it. Behavior adapted from the rwa-interface `RwaRichTooltip`.
class TradeTooltip extends StatefulWidget {
  const TradeTooltip({super.key, required this.message, required this.child, this.tooltipKey});
  final String message;
  final Widget child;
  final Key? tooltipKey;

  @override
  State<TradeTooltip> createState() => _TradeTooltipState();
}

class _TradeTooltipState extends State<TradeTooltip> {
  static const _maxWidth = 288.0, _margin = 12.0, _gap = 4.0;
  final _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) return _hide();
    final overlay = Overlay.of(context);
    final target = context.findRenderObject()! as RenderBox;
    final area = overlay.context.findRenderObject()! as RenderBox;
    final origin = target.localToGlobal(Offset.zero, ancestor: area);
    final width = math.min(_maxWidth, math.max(0.0, area.size.width - _margin * 2));
    final left = origin.dx + target.size.width - width;
    final shift = left.clamp(_margin, math.max(_margin, area.size.width - width - _margin)) - left;
    final below = origin.dy - MediaQuery.paddingOf(context).top < 120;
    final entry = OverlayEntry(
      builder: (_) => _TooltipOverlay(
        link: _link,
        message: widget.message,
        tooltipKey: widget.tooltipKey,
        below: below,
        width: width,
        offset: Offset(shift, below ? _gap : -_gap),
        // Keep the arrow over the target when the bubble is shifted inward.
        arrowInset: math.max(0.0, shift),
        onDismiss: _hide,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: Semantics(
      button: true,
      hint: widget.message,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle, child: widget.child),
    ),
  );
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.link,
    required this.message,
    required this.tooltipKey,
    required this.below,
    required this.width,
    required this.offset,
    required this.arrowInset,
    required this.onDismiss,
  });
  final LayerLink link;
  final String message;
  final Key? tooltipKey;
  final bool below;
  final double width, arrowInset;
  final Offset offset;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // The 36×7 arrow frame overlaps the body border by 1 px, as designed.
    final arrow = Padding(
      padding: EdgeInsets.only(right: arrowInset),
      child: Transform.translate(
        offset: Offset(0, below ? 1 : -1),
        child: RotatedBox(
          quarterTurns: below ? 2 : 0,
          child: SvgPicture.asset('assets/trade/tooltip-arrow.svg', width: 36, height: 7),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onDismiss),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: below ? Alignment.bottomRight : Alignment.topRight,
          followerAnchor: below ? Alignment.topRight : Alignment.bottomRight,
          offset: offset,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: onDismiss,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (below) arrow,
                    Container(
                      key: tooltipKey,
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TradeColors.control,
                        border: Border.all(color: TradeColors.card),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message,
                        style: TradeTypography.body.copyWith(
                          fontWeight: FontWeight.w400,
                          color: TradeColors.secondary,
                        ),
                      ),
                    ),
                    if (!below) arrow,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

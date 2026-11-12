import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/drag_throttle.dart';

/// Shown-unit range of the trade-workspace slider: the smaller directional
/// maximum, so every intermediate amount fits both directions, and the
/// sub-unit precision used when that maximum is one unit or less.
typedef MainOrderSliderScale = ({Decimal maximum, Decimal fine});

/// Trade-workspace order slider. The thumb follows the finger continuously
/// over the designed five stops; positions are committed throttled, as each
/// commit re-sizes and rebuilds the whole order form.
class MainOrderAmountSlider extends StatefulWidget {
  const MainOrderAmountSlider({
    super.key,
    required this.position,
    required this.continuous,
    required this.onCommit,
    required this.semanticLabel,
  });

  /// Committed position, 0–1.
  final double position;

  /// False until a range is known; the thumb then snaps to the five stops.
  final bool continuous;
  final ValueChanged<double>? onCommit;
  final String Function(double position) semanticLabel;

  @override
  State<MainOrderAmountSlider> createState() => _MainOrderAmountSliderState();
}

class _MainOrderAmountSliderState extends State<MainOrderAmountSlider> {
  late final _throttle = DragThrottle<double>((value) => widget.onCommit?.call(value));
  double? _drag;

  @override
  void didUpdateWidget(MainOrderAmountSlider old) {
    super.didUpdateWidget(old);
    // A drag cut off by disabling never reports its end; drop its local value.
    if (widget.onCommit == null) {
      _throttle.cancel();
      _drag = null;
    }
  }

  @override
  void dispose() {
    _throttle.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onCommit != null;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, disabledThumbRadius: 6),
        overlayShape: SliderComponentShape.noOverlay,
        trackShape: widget.continuous ? const _StopTrackShape() : null,
      ),
      child: SizedBox(
        height: 24,
        child: Semantics(
          container: true,
          child: Slider(
            key: const Key('main-order-percentage'),
            divisions: widget.continuous ? null : 4,
            value: (_drag ?? widget.position).clamp(0, 1),
            semanticFormatterCallback: widget.semanticLabel,
            onChanged: enabled
                ? (value) {
                    setState(() => _drag = value);
                    _throttle.add(value);
                  }
                : null,
            onChangeEnd: enabled
                ? (value) {
                    _throttle.end(value);
                    if (mounted) setState(() => _drag = null);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

/// Default rounded track plus the design's five stop dots, which Flutter only
/// paints for a discrete slider.
class _StopTrackShape extends RoundedRectSliderTrackShape {
  const _StopTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    final tick = sliderTheme.tickMarkShape;
    if (tick == null) return;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    for (var i = 0; i <= 4; i++) {
      tick.paint(
        context,
        Offset(rect.left + rect.width * i / 4, rect.center.dy),
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        textDirection: textDirection,
        thumbCenter: thumbCenter,
        isEnabled: isEnabled,
      );
    }
  }
}

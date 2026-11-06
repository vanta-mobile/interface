import 'package:flutter/material.dart';

/// Which way a number moved, deciding which way its digits roll.
enum NumberTrend { up, down, flat }

/// Compares two *formatted* amounts without going through binary floating
/// point, so the comparison is exact for the decimal strings this app renders.
///
/// Understands the shapes [TokenAmountFormatter] produces: a leading sign, a
/// `$`, grouped integer digits, a fraction, a trailing `%`, and the compact
/// `K`/`M`/`B`/`T` suffixes. Returns null when either side is not a number,
/// such as the `—` placeholder.
NumberTrend? compareFormattedAmounts(String previous, String next) {
  final a = _Parsed.tryParse(previous);
  final b = _Parsed.tryParse(next);
  if (a == null || b == null) return null;
  final order = a.compareTo(b);
  return order == 0
      ? NumberTrend.flat
      : order < 0
      ? NumberTrend.up
      : NumberTrend.down;
}

class _Parsed {
  const _Parsed(this.negative, this.scale, this.integer, this.fraction);

  final bool negative;
  final int scale;
  final String integer;
  final String fraction;

  static const _scales = {'K': 1, 'M': 2, 'B': 3, 'T': 4};

  static _Parsed? tryParse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    // USD helpers render `$-1.20`, while compact USD renders `-$1.2K`.
    if (text.startsWith(r'$')) text = text.substring(1);
    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.startsWith(r'$')) text = text.substring(1);
    if (text.endsWith('%')) text = text.substring(0, text.length - 1);
    var scale = 0;
    if (text.isNotEmpty && _scales.containsKey(text[text.length - 1])) {
      scale = _scales[text[text.length - 1]]!;
      text = text.substring(0, text.length - 1);
    }
    text = text.replaceAll(',', '');
    if (text.isEmpty) return null;
    final parts = text.split('.');
    if (parts.length > 2) return null;
    final integer = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final fraction = parts.length == 2 ? parts[1] : '';
    if (integer.isEmpty || !_digitsOnly(integer)) return null;
    if (fraction.isNotEmpty && !_digitsOnly(fraction)) return null;
    return _Parsed(negative, scale, integer, fraction);
  }

  static bool _digitsOnly(String value) =>
      value.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);

  int compareTo(_Parsed other) {
    final width = fraction.length > other.fraction.length ? fraction.length : other.fraction.length;
    // Normalize suffixes and fractions before comparing. A rounded `1000K`
    // equals `1M`, and zero compares equally regardless of sign or suffix.
    BigInt scaled(_Parsed value) {
      final digits =
          '${value.integer}${value.fraction.padRight(width, '0')}'
          '${'0' * (value.scale * 3)}';
      final magnitude = BigInt.parse(digits);
      return value.negative ? -magnitude : magnitude;
    }

    return scaled(this).compareTo(scaled(other));
  }
}

/// A formatted amount whose changed digits roll into place — upwards when the
/// value rose, downwards when it fell.
///
/// Each character is its own wheel: `$182.40` to `$182.45` turns the last
/// digit and leaves every other character untouched, and the digits stay
/// fully opaque behind a clip so the motion reads as a wheel rather than a
/// cross-fade. Characters are paired from the right, where amounts change.
///
/// Digits render as tabular figures so a wheel keeps its width while it
/// turns; without that a `1` following an `8` would shift the whole row.
///
/// While idle this is a plain [Text] with no running animation, and each
/// transition is kept inside a [RepaintBoundary] so a ticking price never
/// repaints the row around it.
///
/// In a list, give this a key tied to the row's identity (the symbol, say) so
/// a recycled element swaps values instead of rolling between two products.
class AnimatedNumberText extends StatefulWidget {
  const AnimatedNumberText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap = false,
    this.comparisonValue,
    this.trend,
    this.duration,
    this.animateFirstChange = true,
  });

  /// Long enough to read the digits turn; `easeInOutCubic` keeps most of
  /// that travel in the middle of the window rather than front-loading it,
  /// so the perceived motion is roughly half this.
  static const defaultDuration = Duration(milliseconds: 700);
  static const defaultCurve = Curves.easeInOutCubic;

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool softWrap;

  /// Numeric text used only to determine the roll direction when [value]
  /// contains a non-numeric label or asset suffix, such as `0.12 USDC`.
  /// The full [value] is still rendered and its changed digits still roll.
  final String? comparisonValue;

  /// Overrides the direction derived from the previous and next strings.
  final NumberTrend? trend;

  /// Defaults to [defaultDuration]; `Duration.zero` swaps without motion.
  final Duration? duration;

  /// Whether the first value change after mounting should roll. Set this to
  /// false when the first value is initial data rather than a live update.
  final bool animateFirstChange;

  @override
  State<AnimatedNumberText> createState() => _AnimatedNumberTextState();
}

class _AnimatedNumberTextState extends State<AnimatedNumberText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late String _shown = widget.value;
  late String _shownComparison = widget.comparisonValue ?? widget.value;
  String? _outgoing;
  var _trend = NumberTrend.flat;
  var _hasChangedValue = false;

  @override
  void initState() {
    super.initState();
    // Drop back to a plain Text once the roll lands, so nothing keeps
    // ticking between updates.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _outgoing = null);
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _duration;
    if (widget.value == _shown) {
      _shownComparison = widget.comparisonValue ?? widget.value;
      return;
    }
    final previous = _shown;
    final previousComparison = _shownComparison;
    final nextComparison = widget.comparisonValue ?? widget.value;
    final shouldAnimate = widget.animateFirstChange || _hasChangedValue;
    _hasChangedValue = true;
    final trend = widget.trend ?? compareFormattedAmounts(previousComparison, nextComparison);
    _shown = widget.value;
    _shownComparison = nextComparison;
    if (!shouldAnimate || trend == null || !_animationsAllowed) {
      setState(() => _outgoing = null);
      _controller.stop();
      return;
    }
    setState(() {
      _outgoing = previous;
      _trend = trend;
    });
    _controller.forward(from: 0);
  }

  Duration get _duration => widget.duration ?? AnimatedNumberText.defaultDuration;

  bool get _animationsAllowed =>
      !MediaQuery.disableAnimationsOf(context) && _duration > Duration.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pairs the two strings from the right, where amounts change, padding the
  /// shorter one so every wheel has something to turn from.
  static String _alignRight(String value, int width) =>
      value.length >= width ? value.substring(value.length - width) : value.padLeft(width);

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final outgoing = _outgoing;
    if (outgoing == null || !_controller.isAnimating) {
      return Text(_shown, style: style, textAlign: widget.textAlign, softWrap: widget.softWrap);
    }
    final previous = _alignRight(outgoing, _shown.length);
    final rise = _trend == NumberTrend.up ? 1.0 : -1.0;
    final characters = <Widget>[
      for (var index = 0; index < _shown.length; index++)
        if (previous[index] == _shown[index])
          Text(_shown[index], style: style, maxLines: 1, softWrap: false)
        else
          _Wheel(
            from: previous[index],
            to: _shown[index],
            progress: _controller,
            rise: rise,
            style: style,
          ),
    ];
    return RepaintBoundary(
      child: Semantics(
        label: _shown,
        excludeSemantics: true,
        child: widget.softWrap
            ? Wrap(
                alignment: switch (widget.textAlign) {
                  TextAlign.center => WrapAlignment.center,
                  TextAlign.end || TextAlign.right => WrapAlignment.end,
                  _ => WrapAlignment.start,
                },
                children: characters,
              )
            : Row(mainAxisSize: MainAxisSize.min, children: characters),
      ),
    );
  }
}

/// One character turning from [from] to [to] behind a clip.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.from,
    required this.to,
    required this.progress,
    required this.rise,
    required this.style,
  });

  final String from;
  final String to;
  final Animation<double> progress;
  final double rise;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = AnimatedNumberText.defaultCurve.transform(progress.value);
        return Stack(
          children: [
            // The incoming character sizes the wheel, so the row lands on the
            // new width immediately and never jitters mid-turn.
            FractionalTranslation(
              translation: Offset(0, rise * (1 - t)),
              child: Text(to, style: style, maxLines: 1, softWrap: false),
            ),
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(0, -rise * t),
                child: Text(from, style: style, maxLines: 1, softWrap: false),
              ),
            ),
          ],
        );
      },
    ),
  );
}

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A pinch can start after a drag/long press already won the gesture arena.
/// Observe raw touch pointers so that second-finger takeover still works.
class KChartPinch extends StatefulWidget {
  const KChartPinch({
    super.key,
    required this.onSequenceStart,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final VoidCallback onSequenceStart, onStart, onEnd;
  final ValueChanged<double> onUpdate;
  final Widget child;

  @override
  State<KChartPinch> createState() => _KChartPinchState();
}

class _KChartPinchState extends State<KChartPinch> {
  final _pointers = <int, Offset>{};
  double? _initialDistance;

  double get _distance {
    final pair = _pointers.values.take(2).toList();
    return (pair.first - pair.last).distance;
  }

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) widget.onSequenceStart();
    if (event.kind != PointerDeviceKind.touch) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _initialDistance = _distance;
      widget.onStart();
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final initial = _initialDistance;
    if (_pointers.length >= 2 && initial != null && initial > 0) {
      widget.onUpdate(_distance / initial);
    }
  }

  void _end(PointerEvent event) {
    if (_pointers.remove(event.pointer) == null || _initialDistance == null) return;
    widget.onEnd();
    _initialDistance = null;
    if (_pointers.length >= 2) {
      _initialDistance = _distance;
      widget.onStart();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        onPointerPanZoomStart: (_) {
          if (_pointers.isEmpty) widget.onSequenceStart();
        },
        child: widget.child,
      );
}

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// k_chart_plus' scale recognizer wins even one-finger vertical gestures.
/// Forward that intent to the surrounding scroll view without claiming the
/// gesture arena: the package still owns horizontal pan, pinch and long press.
class ChartTouchScroll extends StatefulWidget {
  const ChartTouchScroll({super.key, required this.child});
  final Widget child;
  @override
  State<ChartTouchScroll> createState() => _ChartTouchScrollState();
}

class _ChartTouchScrollState extends State<ChartTouchScroll> {
  final pointers = <int>{};
  Offset? origin;
  Duration? downTime;
  bool vertical = false, horizontal = false;
  void down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    pointers.add(event.pointer);
    if (pointers.length == 1) {
      origin = event.position;
      downTime = event.timeStamp;
      vertical = false;
      horizontal = false;
    } else {
      vertical = false;
      horizontal = true;
    }
  }

  void move(PointerMoveEvent event) {
    if (pointers.length != 1 || !pointers.contains(event.pointer) || origin == null || horizontal) {
      return;
    }
    final delta = event.position - origin!;
    if (!vertical) {
      if ((event.timeStamp - downTime!).inMilliseconds > 300) return;
      if (delta.dx.abs() > 12 && delta.dx.abs() >= delta.dy.abs()) {
        horizontal = true;
        return;
      }
      vertical = delta.dy.abs() > 12 && delta.dy.abs() > delta.dx.abs() * 1.25;
    }
    if (!vertical) return;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    final position = scrollable?.position;
    if (position == null || !position.hasContentDimensions) return;
    final target = (position.pixels - event.delta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.jumpTo(target);
    // The ancestor may accept its drag after this raw event is dispatched.
    // End that activity too: it otherwise ignores the second finger's hit
    // test, preventing a vertical movement from becoming a pinch.
    scheduleMicrotask(() {
      if (mounted && pointers.length == 1 && vertical && position.hasPixels) {
        position.jumpTo(target);
      }
    });
  }

  void end(PointerEvent event) {
    pointers.remove(event.pointer);
    if (pointers.isEmpty) {
      origin = null;
      downTime = null;
      vertical = false;
      horizontal = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: down,
    onPointerMove: move,
    onPointerUp: end,
    onPointerCancel: end,
    child: widget.child,
  );
}

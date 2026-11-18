import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's laid-out height after each layout that changes it.
class MeasuredHeight extends SingleChildRenderObjectWidget {
  const MeasuredHeight({super.key, required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasuredHeight(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMeasuredHeight).onHeight = onHeight;
}

class _RenderMeasuredHeight extends RenderProxyBox {
  _RenderMeasuredHeight(this.onHeight);
  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    // Never rebuild during layout; report once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}

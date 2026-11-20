import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Removes the press overlay from state-switching controls (tabs, segmented
/// choices, filters, checkboxes) beneath it; their selected state is the
/// design's only feedback. Pressable controls keep the theme's overlay.
class NoPressFeedback extends StatelessWidget {
  const NoPressFeedback({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(highlightColor: AppColors.transparent),
    child: child,
  );
}

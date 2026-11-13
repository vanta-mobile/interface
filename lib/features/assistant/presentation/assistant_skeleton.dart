import 'package:flutter/material.dart';

import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';

/// Matches the default ask page while the saved session and history load.
class AssistantSkeleton extends StatelessWidget {
  const AssistantSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SingleChildScrollView(
      key: const Key('assistant-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox.circle(48),
          const SizedBox(height: 24),
          const SkeletonBox(width: 200, height: 22),
          const SizedBox(height: 24),
          const FractionallySizedBox(widthFactor: .85, child: SkeletonBox(height: 16)),
          const SizedBox(height: 24),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              height: 64,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AssistantColors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SkeletonBox(
                    width: 20,
                    height: 20,
                    radius: 10,
                    color: StatusColors.skeletonOnCard,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: .8 - i * .1,
                      child: const SkeletonBox(height: 14, color: StatusColors.skeletonOnCard),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

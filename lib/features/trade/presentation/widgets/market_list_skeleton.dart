import 'package:flutter/material.dart';

import '../../../../core/presentation/status_view.dart';

/// Initial catalog load; existing rows remain visible during refresh.
class MarketListSkeleton extends StatelessWidget {
  const MarketListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const Key('market-list-skeleton'),
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: 7,
    itemBuilder: (context, index) => const ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // Aligns with the favorite toggle column of loaded rows.
            SizedBox(width: 44),
            SkeletonBox.circle(20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 82, height: 10),
                  SizedBox(height: 9),
                  SkeletonBox(width: 48, height: 8),
                ],
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonBox(width: 80, height: 10),
                  SizedBox(height: 9),
                  SkeletonBox(width: 58, height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

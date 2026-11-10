import 'package:flutter/material.dart';

import '../../../core/presentation/status_view.dart';
import '../../portfolio/presentation/portfolio_components.dart';

/// Match the transaction rows while the first account snapshot is pending.
class TransferHistorySkeleton extends StatelessWidget {
  const TransferHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          const PortfolioCard(
            border: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SkeletonBox(width: 72, height: 14),
                      ),
                    ),
                    SizedBox(width: 16),
                    SkeletonBox(width: 64, height: 24, radius: 12),
                  ],
                ),
                SizedBox(height: 8),
                FractionallySizedBox(widthFactor: .85, child: SkeletonBox(height: 20)),
                SizedBox(height: 8),
                FractionallySizedBox(widthFactor: .7, child: SkeletonBox(height: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

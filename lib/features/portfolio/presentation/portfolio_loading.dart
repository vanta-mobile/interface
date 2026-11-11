import 'package:flutter/material.dart';

import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';

class PortfolioListSkeleton extends StatelessWidget {
  const PortfolioListSkeleton({super.key, required this.assets});
  final bool assets;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).accountReadLoading,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 120, height: 14),
            ),
          ),
          for (var i = 0; i < (assets ? 3 : 2); i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  if (assets) ...[const SkeletonBox.circle(32), const SizedBox(width: 8)],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 56, height: 20),
                        SizedBox(height: 8),
                        SkeletonBox(width: 44, height: 14),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FractionallySizedBox(widthFactor: .9, child: SkeletonBox(height: 20)),
                        const SizedBox(height: 8),
                        const FractionallySizedBox(widthFactor: .7, child: SkeletonBox(height: 14)),
                        if (!assets) ...[const SizedBox(height: 16), const SkeletonBox(height: 44)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

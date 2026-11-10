import 'package:flutter/material.dart';

import '../trade_theme.dart';

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
        height: 64,
        child: Row(
          children: [
            SizedBox(width: 44),
            _Placeholder(width: 18, height: 18, circle: true),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Placeholder(width: 82, height: 10),
                  SizedBox(height: 8),
                  _Placeholder(width: 48, height: 8),
                ],
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Placeholder(width: 80, height: 10),
                  SizedBox(height: 8),
                  _Placeholder(width: 58, height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.height, this.circle = false});
  final double width, height;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: TradeColors.card,
      borderRadius: BorderRadius.circular(circle ? width / 2 : 3),
    ),
  );
}

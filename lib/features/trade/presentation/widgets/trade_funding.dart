import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';

class TradeFunding extends ConsumerWidget {
  const TradeFunding({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(currentMarketProvider);
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final seconds = market == null
            ? 0
            : ((market.nextFunding - DateTime.now().millisecondsSinceEpoch) ~/ 1000).clamp(
                0,
                86400,
              );
        final remaining =
            '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'funding'), style: TradeTypography.small),
            const SizedBox(height: 4),
            Text(
              market == null ? '—' : '${market.funding.toStringAsFixed(4)}% / $remaining',
              style: TradeTypography.caption.copyWith(color: TradeColors.text),
            ),
          ],
        );
      },
    );
  }
}

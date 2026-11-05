import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/providers.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import 'market_sheet.dart';
import 'primitives.dart';

class MarketHeader extends ConsumerWidget {
  const MarketHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(currentMarketProvider);
    final base = ref.watch(symbolProvider).replaceAll('USDT', '');
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => showAppSheet<void>(context, const MarketSheet()),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CoinIcon(base: base, size: 29),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: base,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(
                                  text: ' / USDT',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondary),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tr(context, 'perpetual'),
                  style: const TextStyle(fontSize: 10, color: AppColors.accent),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SelectableText(
                  market == null
                      ? '—'
                      : marketNumber(market.price, minimumDecimals: market.precision.priceDecimals),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.8,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (market != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: market.change >= 0 ? AppColors.positiveDepth : AppColors.negativeDepth,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${market.change >= 0 ? '+' : ''}${market.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: market.change >= 0 ? AppColors.positive : AppColors.negative,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: tr(context, 'refresh'),
                onPressed: () {
                  final sync = ref.read(marketSyncProvider);
                  if (sync == null) {
                    ref.invalidate(instrumentsProvider);
                  } else {
                    sync.retry();
                  }
                  ref.invalidate(marketProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  tr(context, 'mark'),
                  market == null
                      ? '—'
                      : marketNumber(market.mark, minimumDecimals: market.precision.priceDecimals),
                ),
              ),
              Expanded(
                child: _Stat(tr(context, 'volume'), market == null ? '—' : compact(market.volume)),
              ),
              Expanded(child: _Funding(market: market)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MutedText(label, size: 10),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    ],
  );
}

class _Funding extends StatelessWidget {
  const _Funding({this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
    builder: (context, _) {
      final seconds = market == null
          ? 0
          : ((market!.nextFunding - DateTime.now().millisecondsSinceEpoch) ~/ 1000).clamp(0, 86400);
      final remaining =
          '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MutedText(tr(context, 'funding'), size: 9),
          const SizedBox(height: 4),
          Text(
            market == null ? '—' : '${market!.funding.toStringAsFixed(4)}%',
            style: const TextStyle(color: AppColors.accent, fontSize: 12),
          ),
          Text(
            market == null ? '—' : remaining,
            style: const TextStyle(color: AppColors.muted, fontSize: 9),
          ),
        ],
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/animated_number_text.dart';
import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/domain/market.dart';
import '../../application/navigation_provider.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'market_sheet.dart';
import 'primitives.dart';
import 'futures_workspace_tabs.dart';
export 'futures_workspace_tabs.dart';

class MarketHeader extends ConsumerWidget {
  const MarketHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(currentMarketProvider);
    final base = ref.watch(symbolProvider).replaceAll('USDT', '');
    final chart = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('trade-market-selector'),
                onTap: () => openMarketSelector(context),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      CoinIcon(base: base, size: 32),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: base),
                                        TextSpan(
                                          text: 'USDT',
                                          style: TradeTypography.symbol.copyWith(
                                            color: TradeColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: TradeTypography.symbol,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: TradeColors.muted,
                                ),
                              ],
                            ),
                            if (!chart)
                              _Change(market: market)
                            else
                              Text(tr(context, 'perpetual'), style: TradeTypography.small),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const FuturesWorkspaceTabs(),
          ],
        ),
        if (chart) ...[const SizedBox(height: 20), _ChartSummary(market: market)],
      ],
    );
  }
}

class _ChartSummary extends StatelessWidget {
  const _ChartSummary({this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final price = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FittingNumber(
              market == null
                  ? '—'
                  : '\$${marketNumber(market!.price, minimumDecimals: market!.precision.priceDecimals)}',
              style: TradeTypography.heading.copyWith(fontSize: 24, height: 32 / 24),
            ),
            const SizedBox(height: 8),
            _Change(market: market),
          ],
        );
        final stats = Column(
          children: [
            _Stat('${l.volume24h} (USDT)', market == null ? '—' : compact(market!.volume)),
            _Stat(l.tradeHigh24h, _number(market?.high)),
            _Stat(l.tradeLow24h, _number(market?.low)),
          ],
        );
        if (constraints.maxWidth < 340 && MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [price, const SizedBox(height: 12), stats],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: price),
            const SizedBox(width: 16),
            Expanded(child: stats),
          ],
        );
      },
    );
  }

  String _number(double? value) =>
      value == null ? '—' : marketNumber(value, minimumDecimals: market!.precision.priceDecimals);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TradeTypography.small.copyWith(color: TradeColors.secondary)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TradeTypography.small.copyWith(
              color: TradeColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Change extends StatelessWidget {
  const _Change({this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) => _FittingNumber(
    market == null ? '—' : '${market!.change > 0 ? '+' : ''}${market!.change.toStringAsFixed(2)}%',
    style: TradeTypography.caption.copyWith(
      color: market == null || market!.change == 0
          ? TradeColors.muted
          : market!.change > 0
          ? TradeColors.accent
          : TradeColors.negative,
    ),
  );
}

class _FittingNumber extends StatelessWidget {
  const _FittingNumber(this.value, {this.style});
  final String value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: AnimatedNumberText(value, style: style, textAlign: TextAlign.left),
  );
}

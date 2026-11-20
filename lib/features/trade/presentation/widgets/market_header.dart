import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/animated_number_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/public_leverage_provider.dart';
import '../../../market/domain/market.dart';
import '../../application/navigation_provider.dart';
import '../../application/providers.dart';
import '../../../portfolio/application/symbol_maximum_leverage_provider.dart';
import '../trade_theme.dart';
import 'market_sheet.dart';
import 'max_leverage_badge.dart';
import 'primitives.dart';
import 'futures_workspace_tabs.dart';
export 'futures_workspace_tabs.dart';

/// The market selector row: coin icon, symbol, leverage badge / change, and
/// workspace tab switcher.  Pinned in the [Scaffold.appBar] whenever the
/// futures workspace is active, so it stays visible while the user scrolls.
class MarketHeaderRow extends ConsumerWidget {
  const MarketHeaderRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(symbolProvider), base = symbol.replaceAll('USDT', '');
    return Row(
      children: [
        Expanded(
          // Only the symbol itself opens the selector, not the blank space after it.
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              key: const Key('trade-market-selector'),
              onTap: () => openMarketSelector(context),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoinIcon(base: base, size: 32),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                              const Icon(Icons.arrow_drop_down, size: 16, color: TradeColors.muted),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Signed brackets first; the public brackets
                              // cover a wallet that has not read them yet.
                              if (ref.watch(symbolMaximumLeverageProvider)[symbol] ??
                                      ref.watch(
                                        publicLeverageProvider.select(
                                          (s) => s.value?[symbol]?.maximumLeverage,
                                        ),
                                      )
                                  case final leverage?) ...[
                                MaxLeverageBadge(leverage, key: const Key('trade-max-leverage')),
                                const SizedBox(width: 4),
                              ],
                              const Flexible(child: _MarketChange()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const FuturesWorkspaceTabs(),
      ],
    );
  }
}

class _MarketChange extends ConsumerWidget {
  const _MarketChange();
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _Change(market: ref.watch(currentMarketProvider));
}

class MarketHeader extends ConsumerWidget {
  const MarketHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    if (chart) {
      // The selector row is pinned in the Scaffold.appBar in chart mode; only
      // the scrollable chart summary remains here.
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_ChartSummary()],
      );
    }
    // The selector row is pinned in the Scaffold.appBar; nothing scrollable here.
    return const SizedBox.shrink();
  }
}

class _ChartSummary extends ConsumerWidget {
  const _ChartSummary();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(currentMarketProvider);
    final l = AppLocalizations.of(context);
    String number(double? value) => value == null
        ? '—'
        : marketNumber(value, minimumDecimals: market?.precision.priceDecimals ?? 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final price = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FittingNumber(
              market == null
                  ? '—'
                  : '\$${marketNumber(market.price, minimumDecimals: market.precision.priceDecimals)}',
              style: TradeTypography.heading.copyWith(fontSize: 24, height: 32 / 24),
            ),
            const SizedBox(height: 8),
            _Change(market: market),
          ],
        );
        final stats = Column(
          children: [
            _Stat('${l.volume24h} (USDT)', market == null ? '—' : compact(market.volume)),
            _Stat(l.tradeHigh24h, number(market?.high)),
            _Stat(l.tradeLow24h, number(market?.low)),
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

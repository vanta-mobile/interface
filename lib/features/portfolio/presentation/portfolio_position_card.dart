import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_components.dart';
import 'portfolio_header.dart';
import 'live_order_screen.dart';

class PortfolioPositionCard extends StatelessWidget {
  const PortfolioPositionCard({
    super.key,
    required this.position,
    required this.preview,
    required this.hidden,
  });
  final PortfolioPosition position;
  final bool preview, hidden;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = position;
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PositionIdentity(position: p, preview: preview),
          const SizedBox(height: 16),
          _PositionAmounts(position: p, hidden: hidden),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Metric(l.entry, _price(p.entry))),
              Expanded(
                child: _Metric(
                  l.portfolioMark,
                  _price(p.mark),
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: _Metric(
                  l.portfolioLiquidation,
                  _price(p.liquidation),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l.accountPositionMargin, style: PortfolioTypography.caption)),
              Text(
                hidden
                    ? '••••'
                    : '${portfolioAmount(p.margin)} ${p.marginAsset ?? l.accountUnitUnavailable}',
                style: PortfolioTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (label, conditional) in [
                (l.portfolioTpsl, true),
                (l.market, false),
                (l.limit, false),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      key: ValueKey('portfolio-position-${p.symbol}-${p.side}-$label'),
                      onPressed: preview
                          ? () => portfolioPreviewNotice(context)
                          : conditional
                          ? () => openPositionTriggers(context, p.symbol, p.side)
                          : () =>
                                openLiveClose(context, p.symbol, p.side, market: label == l.market),
                      style: TextButton.styleFrom(
                        backgroundColor: PortfolioColors.button,
                        foregroundColor: PortfolioColors.text,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(label, style: PortfolioTypography.caption),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _price(Decimal? value) => hidden
      ? '••••'
      : value == null
      ? '—'
      : preview
      ? portfolioUsd(value)
      : portfolioAmount(value);
}

class _PositionIdentity extends StatelessWidget {
  const _PositionIdentity({required this.position, required this.preview});
  final PortfolioPosition position;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = position;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (preview)
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: PortfolioColors.text,
                      child: PortfolioIcon('aapl.svg', size: 14, color: PortfolioColors.background),
                    ),
                  if (preview) const SizedBox(width: 8),
                  Expanded(child: SelectableText(p.symbol, style: PortfolioTypography.heading)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Tag(
                    p.long ? l.buy : l.sell,
                    color: p.long ? PortfolioColors.positive : PortfolioColors.negative,
                  ),
                  if (p.leverage != null) _Tag('${p.leverage}x'),
                  if (p.isolated != null) _Tag(p.isolated! ? l.accountIsolatedMode : l.cross),
                ],
              ),
            ],
          ),
        ),
        if (p.riskPercent != null)
          Column(
            children: [
              const PortfolioIcon('risk.svg', size: 30.17),
              Text(
                '${portfolioAmount(p.riskPercent)}%',
                style: PortfolioTypography.caption.copyWith(color: PortfolioColors.positive),
              ),
            ],
          ),
      ],
    );
  }
}

class _PositionAmounts extends StatelessWidget {
  const _PositionAmounts({required this.position, required this.hidden});
  final PortfolioPosition position;
  final bool hidden;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = position;
    final unit = p.marginAsset ?? l.accountUnitUnavailable;
    final size = p.notional == null
        ? '${portfolioAmount(p.quantity)} ${p.base ?? l.accountUnitUnavailable}'
        : portfolioAmount(p.notional);
    final pnl = p.pnl == null
        ? '—'
        : '${p.pnl! > Decimal.zero ? '+' : ''}${portfolioAmount(p.pnl)}';
    return PortfolioCard(
      radius: 8,
      border: false,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.portfolioPnlUnit(unit),
                  style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  hidden
                      ? '••••'
                      : '$pnl${p.returnPercent == null ? '' : ' (${portfolioPercent(p.returnPercent)})'}',
                  style: PortfolioTypography.section.copyWith(color: portfolioPnlColor(p.pnl)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p.notional == null ? l.quantity : l.portfolioSize(unit),
                  textAlign: TextAlign.right,
                  style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  hidden ? '••••' : size,
                  textAlign: TextAlign.right,
                  style: PortfolioTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.alignment = CrossAxisAlignment.start});
  final String label, value;
  final CrossAxisAlignment alignment;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(label, style: PortfolioTypography.caption.copyWith(color: PortfolioColors.muted)),
      const SizedBox(height: 4),
      Text(value, style: PortfolioTypography.caption),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color?.withValues(alpha: .16),
      border: Border.all(color: PortfolioColors.button),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: PortfolioTypography.caption.copyWith(color: color ?? PortfolioColors.text),
    ),
  );
}

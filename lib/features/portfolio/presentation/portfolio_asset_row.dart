import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/portfolio_overview.dart';
import 'portfolio_asset_details.dart';
import 'portfolio_components.dart';

class PortfolioAssetRow extends StatelessWidget {
  const PortfolioAssetRow({
    super.key,
    required this.asset,
    required this.hidden,
    required this.preview,
    this.valuationLoading = false,
  });
  final PortfolioAsset asset;
  final bool hidden, preview, valuationLoading;
  bool get _estimatePending => !hidden && valuationLoading && asset.usd == null;
  bool get _pnlPending => !hidden && valuationLoading && asset.pnl != null && asset.pnlUsd == null;

  @override
  Widget build(BuildContext context) {
    final balance = hidden ? '••••' : portfolioAmount(asset.balance);
    final estimate = hidden
        ? ''
        : ' (${asset.usd == null ? '—' : TokenAmountFormatter.formatUsd(DecimalValue(asset.usd!.toString()))})';
    final available = AppLocalizations.of(context)
        .portfolioAvailable(hidden ? '••••' : portfolioAmount(asset.available));
    final pnl = asset.pnlUsd;
    final pnlText = hidden
        ? '••••'
        : pnl == null
        ? '—'
        : '${pnl < Decimal.zero
              ? '−'
              : pnl > Decimal.zero
              ? '+'
              : ''}${TokenAmountFormatter.formatUsd(DecimalValue(pnl.abs().toString()))}';
    return InkWell(
      onTap: () =>
          showPortfolioAssetDetails(context, asset: asset, hidden: hidden, preview: preview),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _layout(context, constraints, balance, estimate, available, pnlText, pnl),
        ),
      ),
    );
  }

  Widget _identity(String pnlText, Decimal? pnl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(asset.symbol, style: PortfolioTypography.assetSymbol),
      const SizedBox(height: 4),
      if (_pnlPending)
        SkeletonBox(
          key: ValueKey('portfolio-asset-pnl-pending-${asset.symbol}'),
          width: 44,
          height: 18,
        )
      else
        AnimatedNumberText(
          pnlText,
          comparisonValue: hidden ? null : pnl?.toString(),
          softWrap: true,
          style: PortfolioTypography.caption.copyWith(
            color: hidden ? PortfolioColors.secondary : portfolioPnlColor(pnl),
          ),
        ),
    ],
  );

  Widget _amounts(String balance, String estimate, String available) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Rich text keeps quantity and its secondary USD estimate together,
      // wrapping at the space when enlarged text needs another line.
      Text.rich(
        TextSpan(
          text: balance,
          children: [
            if (_estimatePending)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: SkeletonBox(
                    key: ValueKey('portfolio-asset-value-pending-${asset.symbol}'),
                    width: 48,
                    height: 14,
                  ),
                ),
              )
            else
              TextSpan(
                text: estimate,
                style: const TextStyle(color: PortfolioColors.assetEstimate),
              ),
          ],
        ),
        textAlign: TextAlign.right,
        style: PortfolioTypography.section,
      ),
      const SizedBox(height: 4),
      AnimatedNumberText(
        available,
        comparisonValue: hidden ? null : asset.available?.toString(),
        textAlign: TextAlign.right,
        softWrap: true,
        style: PortfolioTypography.caption,
      ),
    ],
  );

  Widget _layout(
    BuildContext context,
    BoxConstraints constraints,
    String balance,
    String estimate,
    String available,
    String pnlText,
    Decimal? pnl,
  ) {
    final identity = _identity(pnlText, pnl);
    final amounts = _amounts(balance, estimate, available);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final identityWidth = math.max(
      width(asset.symbol, PortfolioTypography.assetSymbol),
      width(pnlText, PortfolioTypography.caption),
    );
    final amountWidth = math.max(
      _estimatePending
          ? width(balance, PortfolioTypography.section) + 52
          : width('$balance$estimate', PortfolioTypography.section),
      width(available, PortfolioTypography.caption),
    );
    final stacked = 40 + identityWidth + 16 + amountWidth > constraints.maxWidth;
    final leading = Row(
      children: [
        PortfolioAssetBadge(symbol: asset.symbol),
        const SizedBox(width: 8),
        if (stacked) Expanded(child: identity) else identity,
      ],
    );
    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [leading, const SizedBox(height: 8), amounts],
          )
        : Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(child: amounts),
            ],
          );
  }
}

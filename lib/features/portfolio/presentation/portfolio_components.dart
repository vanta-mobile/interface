import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/theme.dart';

String portfolioUsd(Decimal? value, {bool signed = false}) {
  if (value == null) return '—';
  final amount = TokenAmountFormatter.formatUsdFixed(
    DecimalValue(value.abs().toString()),
    fractionDigits: 2,
    preserveSmallValues: true,
  );
  return '${value < Decimal.zero
      ? '−'
      : signed && value > Decimal.zero
      ? '+'
      : ''}$amount';
}

String portfolioAmount(Decimal? value) =>
    value == null ? '—' : TokenAmountFormatter.formatText(value.toString());
String portfolioPercent(Decimal? value) =>
    value == null ? '—%' : '${value > Decimal.zero ? '+' : ''}${portfolioAmount(value)}%';

Color portfolioPnlColor(Decimal? value) => value == null
    ? PortfolioColors.secondary
    : value < Decimal.zero
    ? PortfolioColors.negative
    : PortfolioColors.accent;

class PortfolioIcon extends StatelessWidget {
  const PortfolioIcon(this.asset, {super.key, this.size = 20, this.color});
  final String asset;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: SvgPicture.asset(
        'assets/portfolio/$asset',
        colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    ),
  );
}

class PortfolioCard extends StatelessWidget {
  const PortfolioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.border = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: PortfolioColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: PortfolioColors.line) : null,
    ),
    child: child,
  );
}

class PortfolioMetric extends StatelessWidget {
  const PortfolioMetric({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.color = PortfolioColors.text,
    this.large = false,
    this.loading = false,
    this.skeletonColor = StatusColors.skeleton,
  });
  final String label, value;
  final String? note;
  final Color color, skeletonColor;
  final bool large, loading;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: PortfolioTypography.caption),
      const SizedBox(height: 4),
      if (loading)
        SkeletonBox(width: large ? 160 : 96, height: large ? 36 : 22, color: skeletonColor)
      else
        AnimatedNumberText(
          value,
          softWrap: true,
          style: (large ? PortfolioTypography.value : PortfolioTypography.metric).copyWith(
            color: color,
          ),
        ),
      if (note != null && !loading) ...[
        const SizedBox(height: 4),
        Text(note!, style: PortfolioTypography.caption.copyWith(color: color)),
      ],
    ],
  );
}

class PortfolioEmpty extends StatelessWidget {
  const PortfolioEmpty(this.message, {super.key, this.height = 96});
  final String message;
  final double height;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: height),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, textAlign: TextAlign.center, style: PortfolioTypography.caption),
      ),
    ),
  );
}

class PortfolioAction extends StatelessWidget {
  const PortfolioAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      backgroundColor: primary ? PortfolioColors.accent : PortfolioColors.button,
      foregroundColor: primary ? PortfolioColors.onAccent : PortfolioColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: PortfolioTypography.section,
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/trade_icon.dart';
import '../domain/scaled_order.dart';

/// Distribution label with its explanation, and Preview once filled in.
class ScaledDistributionRow extends StatelessWidget {
  const ScaledDistributionRow({super.key, required this.onInfo, required this.onPreview});
  final VoidCallback onInfo;
  final VoidCallback? onPreview;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: InkWell(
            key: const Key('scaled-distribution-info-open'),
            onTap: onInfo,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.scaledDistributionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TradeTypography.caption,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const TradeIcon('scaled-info', size: 12, color: TradeColors.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Not shown until the inputs make a plan.
        if (onPreview case final open?)
          InkWell(
            key: const Key('scaled-preview'),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.scaledPreviewLink,
                    style: TradeTypography.caption.copyWith(
                      color: TradeColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const TradeIcon('scaled-preview', size: 12, color: TradeColors.text),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bordered chip: distribution picker, and the constant switch for
/// increasing and decreasing distributions.
class ScaledDistributionChip extends StatelessWidget {
  const ScaledDistributionChip({
    super.key,
    required this.label,
    required this.constant,
    required this.onDistribution,
    required this.onConstant,
  });
  final String label;
  final ScaledConstant? constant;
  final VoidCallback? onDistribution, onConstant;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: TradeColors.card),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          InkWell(
            key: const Key('scaled-distribution'),
            onTap: onDistribution,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TradeTypography.caption.copyWith(color: TradeColors.text)),
                  const Icon(Icons.arrow_drop_down, size: 14, color: TradeColors.text),
                ],
              ),
            ),
          ),
          if (constant case final value?) ...[
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                key: const Key('scaled-constant'),
                onTap: onConstant,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value == ScaledConstant.ratio
                              ? l10n.scaledConstRatio
                              : l10n.scaledConstDifference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TradeTypography.caption.copyWith(color: TradeColors.secondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const TradeIcon('scaled-swap', size: 12, color: TradeColors.secondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

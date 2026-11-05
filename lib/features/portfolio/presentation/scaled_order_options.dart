import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/scaled_order.dart';

String scaledDistributionLabel(AppLocalizations l10n, ScaledDistribution value) => switch (value) {
  ScaledDistribution.equal => l10n.scaledEqual,
  ScaledDistribution.increasing => l10n.scaledIncreasing,
  ScaledDistribution.decreasing => l10n.scaledDecreasing,
  ScaledDistribution.random => l10n.scaledRandom,
};

String scaledConstantLabel(AppLocalizations l10n, ScaledConstant value) => switch (value) {
  ScaledConstant.difference => l10n.scaledDifference,
  ScaledConstant.ratio => l10n.scaledRatio,
};

class ScaledUnitControl extends StatelessWidget {
  const ScaledUnitControl({
    super.key,
    required this.unit,
    required this.baseAsset,
    required this.quoteAsset,
    required this.enabled,
    required this.onChanged,
  });
  final ScaledSizeUnit unit;
  final String baseAsset, quoteAsset;
  final bool enabled;
  final ValueChanged<ScaledSizeUnit> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final value in ScaledSizeUnit.values)
        ChoiceChip(
          key: ValueKey('scaled-unit-${value.name}'),
          label: Text(value == ScaledSizeUnit.base ? baseAsset : quoteAsset),
          selected: unit == value,
          onSelected: enabled ? (_) => onChanged(value) : null,
        ),
    ],
  );
}

class ScaledDistributionControl extends StatelessWidget {
  const ScaledDistributionControl({
    super.key,
    required this.distribution,
    required this.constant,
    required this.enabled,
    required this.onDistribution,
    required this.onConstant,
  });
  final ScaledDistribution distribution;
  final ScaledConstant constant;
  final bool enabled;
  final ValueChanged<ScaledDistribution> onDistribution;
  final ValueChanged<ScaledConstant> onConstant;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progressive =
        distribution == ScaledDistribution.increasing ||
        distribution == ScaledDistribution.decreasing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scaledDistribution),
        Wrap(
          spacing: 8,
          children: [
            for (final value in ScaledDistribution.values)
              ChoiceChip(
                key: ValueKey('scaled-distribution-${value.name}'),
                label: Text(scaledDistributionLabel(l10n, value)),
                selected: distribution == value,
                onSelected: enabled ? (_) => onDistribution(value) : null,
              ),
          ],
        ),
        if (progressive) ...[
          Text(l10n.scaledConstant),
          Wrap(
            spacing: 8,
            children: [
              for (final value in ScaledConstant.values)
                ChoiceChip(
                  key: ValueKey('scaled-constant-${value.name}'),
                  label: Text(scaledConstantLabel(l10n, value)),
                  selected: constant == value,
                  onSelected: enabled ? (_) => onConstant(value) : null,
                ),
            ],
          ),
          Text(
            constant == ScaledConstant.difference
                ? l10n.scaledDifferenceHint
                : l10n.scaledRatioHint,
          ),
        ],
      ],
    );
  }
}

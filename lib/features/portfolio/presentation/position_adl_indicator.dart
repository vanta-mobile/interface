import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/position_adl_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/position_risk.dart';

class PositionAdlIndicator extends ConsumerWidget {
  const PositionAdlIndicator({super.key, required this.position});
  final PositionRisk position;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(positionAdlProvider);
    final riskStale = ref.watch(positionRiskProvider.select((s) => s.stale));
    final level = state.account?.levelFor(position);
    final stale = state.stale || riskStale;
    final description = position.balanceOnly
        ? l10n.positionAdlNotApplicable
        : level == null
        ? l10n.positionAdlUnknown
        : stale
        ? l10n.positionAdlHistorical(level)
        : l10n.positionAdlLevel(level);
    return Semantics(
      label: '${l10n.positionAdlTitle}: $description',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(l10n.positionAdlTitle, style: Theme.of(context).textTheme.bodySmall),
              if (level != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        key: Key('adl-${position.symbol}-${position.side}-$i'),
                        width: 4,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: i < level ? AppColors.negative : AppColors.muted,
                      ),
                  ],
                ),
              Text(
                description,
                style: TextStyle(color: stale ? AppColors.warning : AppColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

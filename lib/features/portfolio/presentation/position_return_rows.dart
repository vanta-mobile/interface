import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/position_returns.dart';
import '../domain/position_risk.dart';

class PositionReturnRows extends StatelessWidget {
  const PositionReturnRows({
    super.key,
    required this.position,
    required this.mark,
    required this.pnl,
    required this.publicMark,
  });
  final PositionRisk position;
  final Decimal? mark, pnl;
  final bool publicMark;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = PositionReturns(position: position, mark: mark, pnl: pnl);
    final roi = values.roePercent;
    final unit = position.units?.margin ?? l10n.accountUnitUnavailable;
    String amount(Decimal? value) => value == null ? '—' : '${marketNumber(value)} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          position.isolated ? l10n.positionAllocatedMargin : l10n.positionEstimatedCrossMargin,
          amount(values.margin),
        ),
        ValueRow(l10n.positionEstimatedInitialMargin, amount(values.initialMargin)),
        ValueRow(
          publicMark ? l10n.positionEstimatedRoe : l10n.positionSnapshotRoe,
          roi == null ? '—' : '${roi > Decimal.zero ? '+' : ''}${roi.toStringAsFixed(2)}%',
          color: roi == null || roi == Decimal.zero
              ? AppColors.text
              : roi > Decimal.zero
              ? AppColors.positive
              : AppColors.negative,
        ),
        Text(l10n.positionReturnScope, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

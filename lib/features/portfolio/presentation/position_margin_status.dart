import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_margin_provider.dart';
import '../domain/position_margin_adjustment.dart';

class PositionMarginStatus extends ConsumerWidget {
  const PositionMarginStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), state = ref.watch(positionMarginProvider);
    final result = state.result, failure = state.failure ?? state.result?.failure;
    final controller = ref.read(positionMarginProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy) ...[
          const LinearProgressIndicator(),
          Text(switch (state.step) {
            MarginAdjustmentStep.signing => l.accountReadSigning,
            MarginAdjustmentStep.submitting => l.marginAdjustSubmitting,
            MarginAdjustmentStep.checking => l.marginAdjustChecking,
            _ => l.accountReadLoading,
          }),
          TextButton(
            key: const Key('margin-adjust-stop'),
            onPressed: controller.stop,
            child: Text(l.marginAdjustStop),
          ),
        ],
        if (failure != null)
          Text(
            accountErrorText(context, failure),
            key: const Key('margin-adjust-error'),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (result?.verified == true)
          Text(l.marginAdjustVerified, key: const Key('margin-adjust-verified')),
        if (result?.position case final p?)
          ValueRow(
            l.marginAdjustActualLiquidation,
            p.balanceOnly || p.liquidationPrice == null || p.liquidationPrice! <= Decimal.zero
                ? '—'
                : '${p.liquidationPrice} ${p.units?.quote ?? l.accountUnitUnavailable}',
          ),
      ],
    );
  }
}

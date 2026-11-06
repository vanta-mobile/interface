import '../../../core/errors/error_text.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_risk_provider.dart';
import '../domain/live_order.dart';

class LiveCloseResult extends ConsumerWidget {
  const LiveCloseResult({super.key, required this.intent, required this.result});
  final LiveOrderIntent intent;
  final LiveOrderResult result;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), risk = ref.watch(positionRiskProvider);
    final auth = ref.watch(authProvider), snapshot = risk.account;
    final verified =
        snapshot != null &&
        !risk.stale &&
        !risk.busy &&
        risk.failure == null &&
        result.checkedAt != null &&
        !snapshot.receivedAt.isBefore(result.checkedAt!) &&
        snapshot.address.toLowerCase() == intent.context.address.toLowerCase();
    final quantity = verified
        ? snapshot.positions
                  .where((p) => p.symbol == intent.context.symbol && p.side == intent.positionSide)
                  .firstOrNull
                  ?.quantity ??
              Decimal.zero
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.liveCloseResultScope),
        OutlinedButton(
          key: const Key('live-close-read-remaining'),
          onPressed:
              risk.busy ||
                  auth.busy ||
                  auth.identity?.signingAvailable != true ||
                  auth.identity?.walletAddress?.toLowerCase() !=
                      intent.context.address.toLowerCase()
              ? null
              : () => ref.read(positionRiskProvider.notifier).refresh(),
          child: Text(l10n.liveCloseReadRemaining),
        ),
        if (risk.busy) const LinearProgressIndicator(),
        if (quantity != null)
          ValueRow(l10n.liveCloseRemaining, '${quantity.abs()} ${intent.context.rules.baseAsset}'),
        if (quantity != null) Text('${snapshot!.receivedAt.toUtc().toIso8601String()} UTC'),
        if (risk.failure case final failure?)
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
          ),
      ],
    );
  }
}

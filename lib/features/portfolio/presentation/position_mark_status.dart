import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/mark_prices.dart';
import '../application/position_mark_prices_provider.dart';
import '../application/position_risk_provider.dart';

class PositionMarkStatus extends ConsumerWidget {
  const PositionMarkStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final symbols = ref.watch(
      positionRiskProvider.select(
        (s) => s.account?.positions.where((p) => !p.balanceOnly).map((p) => p.symbol).toSet(),
      ),
    );
    final summary = ref.watch(
      positionMarkPricesProvider.select(
        (s) => (
          s.value?.fresh.length ?? 0,
          s.hasError ||
              s.value?.connection == MarkPriceConnection.offline ||
              s.value?.invalid.isNotEmpty == true ||
              s.value?.snapshotFailed == true,
        ),
      ),
    );
    final count = summary.$1;
    final failed = summary.$2 && count < (symbols?.length ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            symbols == null || symbols.isEmpty
                ? l10n.positionMarkReadFirst
                : l10n.positionMarkCoverage(count, symbols.length),
            key: const Key('position-mark-status'),
          ),
          const SizedBox(height: 6),
          Text(l10n.positionMarkScope, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(l10n.positionReturnScope, style: Theme.of(context).textTheme.bodySmall),
          if (symbols?.isNotEmpty == true) ...[
            if (failed) Text(l10n.positionMarkUnavailable),
            OutlinedButton.icon(
              key: const Key('retry-position-marks'),
              onPressed: () => ref.read(positionMarkRepositoryProvider)?.reconnect(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.positionMarkRetry),
            ),
          ],
        ],
      ),
    );
  }
}

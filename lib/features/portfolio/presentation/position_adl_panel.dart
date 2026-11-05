import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/position_adl_provider.dart';
import '../application/position_risk_provider.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';

class PositionAdlPanel extends ConsumerWidget {
  const PositionAdlPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(positionAdlProvider);
    final riskBusy = ref.watch(positionRiskProvider.select((s) => s.busy));
    return ExpansionTile(
      key: const Key('position-adl-panel'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      title: Text(l10n.positionAdlTitle),
      children: [
        Text(l10n.positionAdlScope),
        const SizedBox(height: 12),
        AccountReadControls(
          state: state,
          enabled: !riskBusy,
          buttonKey: const Key('read-position-adl'),
          initialLabel: l10n.positionAdlRead,
          refreshLabel: l10n.positionAdlRefresh,
          onRead: () => ref.read(positionAdlProvider.notifier).refresh(),
        ),
        AccountSnapshotStatus(
          state: state,
          timeKey: const Key('position-adl-time'),
          staleKey: const Key('position-adl-stale'),
        ),
        if (state.account?.symbols.isEmpty == true) Text(l10n.positionAdlEmpty),
      ],
    );
  }
}

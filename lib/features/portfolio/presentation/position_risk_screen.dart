import 'position_margin_history.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart';
import '../application/position_risk_provider.dart';
import '../application/position_adl_provider.dart';
import 'account_read_controls.dart';
import 'account_snapshot_status.dart';
import 'position_risk_card.dart';
import 'position_adl_panel.dart';
import 'position_mark_status.dart';
import 'account_change_panel.dart';
import 'account_event_status.dart';
import 'position_settings_entries.dart';
import '../application/batch_close_provider.dart';
import 'batch_close_controls.dart';
import 'batch_close_status.dart';
import '../../../core/presentation/status_view.dart';

class PositionRiskScreen extends ConsumerStatefulWidget {
  const PositionRiskScreen({super.key, this.embedded = false, this.symbol});
  final String? symbol;
  final bool embedded;
  @override
  ConsumerState<PositionRiskScreen> createState() => _PositionRiskScreenState();
}

class _PositionRiskScreenState extends ConsumerState<PositionRiskScreen> {
  bool currentOnly = false;
  @override
  void initState() {
    super.initState();
    currentOnly = widget.symbol != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(positionRiskProvider);
    final address = ref.watch(authProvider.select((s) => s.identity?.walletAddress));
    final symbol = widget.symbol ?? ref.watch<String>(symbolProvider);
    final all = state.account?.positions;
    final positions = all?.where((p) => !currentOnly || p.symbol == symbol).toList();
    final children = <Widget>[
      Text(l10n.positionRiskScope),
      PositionSettingsEntries(symbol: symbol),
      const PositionMarkStatus(),
      if (address != null) ...[
        const SizedBox(height: 12),
        SelectableText(address, key: const Key('position-risk-wallet')),
      ],
      const SizedBox(height: 16),
      AccountReadControls(
        state: state,
        buttonKey: const Key('read-position-risk'),
        initialLabel: l10n.positionRiskRead,
        refreshLabel: l10n.positionRiskRefresh,
        enabled:
            !ref.watch(positionAdlProvider.select((s) => s.busy)) &&
            !ref.watch(batchCloseProvider.select((s) => s.busy)),
        failureView: true,
        onRead: () => ref.read(positionRiskProvider.notifier).refresh(),
      ),
      AccountSnapshotStatus(
        state: state,
        timeKey: const Key('position-risk-time'),
        staleKey: const Key('position-risk-stale'),
      ),
      const PositionAdlPanel(),
      const AccountChangePanel(),
      const PositionMarginHistoryEntry(),
      AccountEventStatus(time: state.account?.lastEventAt),
      BatchCloseControls(symbol: currentOnly ? symbol : null),
      const BatchCloseStatus(),
      if (all != null) ...[
        SwitchListTile(
          key: const Key('position-risk-current-symbol'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.openOrdersCurrentSymbol),
          subtitle: SelectableText(symbol),
          value: currentOnly,
          onChanged: (value) => setState(() => currentOnly = value),
        ),
        Text(
          l10n.positionRiskCount(positions!.length),
          key: const Key('position-risk-count'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (positions.isEmpty)
          StatusEmptyView(
            key: const Key('position-risk-empty'),
            message: currentOnly && all.isNotEmpty
                ? l10n.positionRiskNoCurrent
                : l10n.accountNoPositions,
          ),
        for (final position in positions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PositionRiskCard(position: position),
          ),
      ],
    ];
    if (widget.embedded) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.positionRiskTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(positionRiskProvider.notifier).refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const Key('position-risk-page'),
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ),
    );
  }
}

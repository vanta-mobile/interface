import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/points_provider.dart';
import '../domain/points.dart';
import 'points_status.dart';

class WalletPointsPanel extends ConsumerWidget {
  const WalletPointsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), identity = ref.watch(authProvider).identity;
    final address = identity?.walletAddress;
    final valid = address != null && isPointsEvmAddress(address);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pointsMyPoints, style: Theme.of(context).textTheme.titleLarge),
          if (valid) ...[
            SelectableText(address, key: const Key('points-wallet-address')),
            Text(l10n.pointsWalletReadScope),
            _WalletPointsContent(
              key: ValueKey('${identity!.id}:${identity.walletKind}:$address'),
              address: address,
            ),
          ] else ...[
            ValueRow(l10n.pointsMyTotal, '—'),
            ValueRow(l10n.pointsCurrentScore, '—'),
            Text(l10n.pointsWalletRequired),
            OutlinedButton(
              key: const Key('points-connect'),
              onPressed: () => showAccountSheet(context),
              child: Text(l10n.pointsConnectWallet),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletPointsContent extends ConsumerWidget {
  const _WalletPointsContent({super.key, required this.address});
  final String address;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(walletPointsProvider);
    final history = ref.watch(walletPointsHistoryProvider),
        ranking = ref.watch(pointsLeaderboardProvider(null));
    final value = state.snapshot?.value;
    final rank = ranking.snapshot?.value.rankFor(address);
    String amount(Object? value) => value == null ? '—' : marketNumber(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.pointsMyTotal, amount(value?.total)),
        ValueRow(l10n.pointsCurrentScore, amount(value?.current)),
        ValueRow(l10n.pointsSettled, amount(value?.settled)),
        ValueRow(l10n.pointsSpecial, amount(value?.special)),
        if (value != null)
          Text(rank == null ? l10n.pointsRankUnknown : l10n.pointsRankNumber('$rank')),
        if (value != null && ranking.stale) Text(l10n.pointsStale),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('points-read-wallet'),
          onPressed: !state.active || state.loading || history.loading
              ? null
              : () => unawaited(
                  Future.wait([
                    ref.read(walletPointsProvider.notifier).refresh(),
                    ref.read(walletPointsHistoryProvider.notifier).refresh(),
                  ]),
                ),
          child: Text(l10n.pointsReadWallet),
        ),
        PointsStatus(
          state: state,
          onRefresh: ref.read(walletPointsProvider.notifier).refresh,
          onStop: ref.read(walletPointsProvider.notifier).stop,
          sectionKey: 'wallet',
        ),
        const SizedBox(height: 8),
        const _WalletPointsHistory(),
      ],
    );
  }
}

class _WalletPointsHistory extends ConsumerStatefulWidget {
  const _WalletPointsHistory();
  @override
  ConsumerState<_WalletPointsHistory> createState() => _WalletPointsHistoryState();
}

class _WalletPointsHistoryState extends ConsumerState<_WalletPointsHistory> {
  int? campaign;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), history = ref.watch(walletPointsHistoryProvider);
    final value = ref.watch(walletPointsProvider).snapshot?.value;
    final entries = history.snapshot?.value.rows ?? const <WalletCampaignPoints>[];
    final selected = entries.where((e) => e.campaign == campaign).firstOrNull;
    String amount(Object? value) => value == null ? '—' : marketNumber(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('points-history-select-$campaign'),
          initialValue: campaign ?? 0,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(labelText: l10n.pointsSelectHistory),
          items: [
            DropdownMenuItem(value: 0, child: Text(l10n.pointsAccumulated)),
            for (final row in entries)
              DropdownMenuItem(
                value: row.campaign,
                child: Text(
                  row.name.isEmpty ? l10n.pointsCycleNumber('${row.campaign}') : row.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (campaign != null && selected == null)
              DropdownMenuItem(value: campaign, child: Text(l10n.pointsCycleNumber('$campaign'))),
          ],
          onChanged: (value) => setState(() => campaign = value == 0 ? null : value),
        ),
        ValueRow(
          l10n.pointsSelectedHistory,
          amount(campaign == null ? value?.total : selected?.points),
        ),
        if (history.snapshot != null && entries.isEmpty) Text(l10n.pointsNoHistory),
        PointsStatus(
          state: history,
          onRefresh: ref.read(walletPointsHistoryProvider.notifier).refresh,
          onStop: ref.read(walletPointsHistoryProvider.notifier).stop,
          sectionKey: 'history',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'attached_entry_pricing.dart';
import 'live_order_pricing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/order_recovery_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/order_recovery.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_trigger.dart';
import 'attached_exit_preview.dart';
import 'strategy_execution_screen.dart';

void openOrderRecovery(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const OrderRecoveryScreen()));

class OrderRecoveryScreen extends ConsumerWidget {
  const OrderRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), auth = ref.watch(authProvider);
    final storage = ref.watch(orderRecoverySnapshotProvider),
        check = ref.watch(orderRecoveryProvider);
    final records = ref.watch(pendingWalletOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderRecoveryTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('order-recovery-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.orderRecoveryScope),
            if (auth.identity?.walletAddress case final address?) SelectableText(address),
            if (auth.identity?.signingAvailable != true)
              OutlinedButton(
                key: const Key('order-recovery-connect'),
                onPressed: auth.busy ? null : () => showAccountSheet(context),
                child: Text(l10n.orderRecoveryConnect),
              ),
            if (!storage.ready || check.busy) const LinearProgressIndicator(),
            if (storage.failure != null) ...[
              Text(l10n.orderRecoveryStorage, style: const TextStyle(color: AppColors.negative)),
              OutlinedButton(
                key: const Key('order-recovery-reload'),
                onPressed: ref.read(orderRecoverySnapshotProvider.notifier).retry,
                child: Text(l10n.orderRecoveryReload),
              ),
            ],
            if (storage.ready && storage.failure == null && records.isEmpty)
              Text(l10n.orderRecoveryEmpty),
            for (final record in records) _RecoveryCard(record: record),
            if (check.record != null && !check.busy) _RecoveryResult(check: check),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends ConsumerWidget {
  const _RecoveryCard({required this.record});
  final OrderRecoveryRecord record;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), query = record.query;
    final check = ref.watch(orderRecoveryProvider), auth = ref.watch(authProvider);
    final activity = ref.watch(symbolSettingsActivityProvider);
    final storage = ref.watch(orderRecoverySnapshotProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(query.symbol),
            SelectableText(query.clientOrderId),
            Text(query.draft.attachment?.strategyType ?? query.draft.orderType),
            Text('${query.side} · ${query.positionSide}'),
            if (query.draft.attachment?.entryPeg case final peg?)
              AttachedEntryPegSummary(peg: peg, showEstimate: false),
            if (query.draft.attachment case final attachment?) ...[
              ValueRow(l10n.attachedOrderExitQuantity, query.protectedQuantity!),
              for (final exit in attachment.exits) ...[
                Text(
                  exit.kind == LiveOrderTriggerKind.takeProfit
                      ? l10n.attachedOrderTakeProfit
                      : l10n.attachedOrderStopLoss,
                ),
                ValueRow(
                  exit.basis == LiveOrderTriggerBasis.mark
                      ? l10n.openOrdersMarkPrice
                      : l10n.openOrdersLastPrice,
                  '${exit.rises(!query.draft.buy) ? '≥' : '≤'} ${exit.price}',
                ),
                ValueRow(l10n.attachedOrderExecution, attachedExecutionLabel(l10n, exit.execution)),
                if (!exit.market) SelectableText(exit.executionPrice!),
              ],
              Text(
                attachment.drivenOn == AttachedOrderDrivenOn.filled
                    ? l10n.attachedOrderLegacyLifecycle
                    : l10n.attachedOrderLifecycle,
              ),
            ],
            if (query.draft.peg case final peg?) LiveOrderPegSummary(peg: peg),
            ValueRow(
              l10n.orderRecoveryCreated,
              DateFormat.yMd(l10n.localeName).add_Hms().format(record.createdAt.toLocal()),
            ),
            Text(l10n.orderRecoveryPending),
            if (activity.owner != null && activity.owner != SymbolSetting.recovery)
              Text(l10n.orderRecoveryActiveOperation),
            OutlinedButton(
              key: ValueKey('recover-${record.key}'),
              onPressed:
                  check.busy ||
                      auth.busy ||
                      auth.identity?.signingAvailable != true ||
                      storage.failure != null ||
                      activity.owner != null && activity.owner != SymbolSetting.recovery
                  ? null
                  : () => ref.read(orderRecoveryProvider.notifier).query(record.key),
              child: Text(l10n.orderRecoveryQuery),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryResult extends StatelessWidget {
  const _RecoveryResult({required this.check});
  final OrderRecoveryCheck check;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), result = check.result;
    final failure = check.failure ?? result?.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(check.record!.query.clientOrderId),
        if (result != null && !result.needsRecheck) ...[
          Text(l10n.orderRecoveryVerified),
          if (result.strategy case final strategy?) ...[
            SelectableText(strategy.strategyId),
            Text(strategy.status),
            for (final leg in strategy.legs) ...[
              ValueRow(l10n.attachedOrderLegStatus(leg.sequence), leg.status),
              if (leg.orderId != null) SelectableText(leg.orderId!),
            ],
            Text(l10n.attachedOrderQueryScope),
            OutlinedButton(
              key: const Key('recovered-strategy-execution'),
              onPressed: () =>
                  openStrategyExecution(context, check.record!.query, strategy.strategyId),
              child: Text(l10n.strategyExecutionTitle),
            ),
          ] else ...[
            SelectableText(result.orderId!),
            Text(
              l10n.liveOrderVerifiedResult(
                result.status!,
                result.executedQuantity.toString(),
                result.orderId!,
              ),
            ),
            Text(l10n.liveOrderQueryScope),
          ],
        ],
        if (failure != null)
          Text(
            '${tr(context, failure.key)}${failure.code == null ? '' : ' ${l10n.accountErrorCode(failure.code!)}'}',
            style: const TextStyle(color: AppColors.negative),
          ),
      ],
    );
  }
}

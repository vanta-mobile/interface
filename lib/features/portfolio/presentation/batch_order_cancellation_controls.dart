import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/app_toast.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/order_cancellation_provider.dart';
import '../domain/order_cancellation.dart';
import 'open_order_cancel_prompts.dart';
import 'order_cancel_progress.dart';

/// The confirmed cancellation shows progress on the trigger button; its
/// outcome is a toast: success once every symbol was verified empty, otherwise
/// the first failure's cause or the count of orders still open.
Future<void> confirmBatchCancellation(BuildContext context, WidgetRef ref, {String? symbol}) async {
  final controller = ref.read(orderCancellationProvider.notifier);
  final intent = await controller.prepareCurrentBatch(symbol: symbol);
  if (intent == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showWarningConfirmSheet(
    context,
    title: l10n.openOrdersCancelAll,
    confirmKey: const Key('confirm-batch-cancel'),
    message: symbol == null
        ? l10n.openOrdersCancelAllQuestion
        : l10n.openOrdersCancelSymbolQuestion(symbol),
  );
  if (!confirmed || !context.mounted) return;
  final current = await controller.renewBatch(intent, symbol: symbol);
  if (current == null) return;
  await controller.cancelBatch(current);
  if (!context.mounted) return;
  _showBatchOutcome(context, ref.read(orderCancellationProvider).batch, current);
}

void _showBatchOutcome(
  BuildContext context,
  BatchCancellationState? batch,
  BatchCancelIntent intent,
) {
  if (batch == null || batch.busy || batch.intent.address != intent.address) return;
  final l10n = AppLocalizations.of(context);
  final results = batch.results.values;
  final failure = results
      .map((result) => result.failure)
      .firstWhere((failure) => failure != null, orElse: () => null);
  final remaining = results.fold(0, (sum, result) => sum + (result.snapshot?.orders.length ?? 0));
  if (failure != null) {
    AppToast.showFailure(context, accountErrorText(context, failure));
  } else if (remaining > 0) {
    AppToast.showFailure(context, l10n.batchCancelRemaining(remaining));
  } else if (results.isNotEmpty && results.every((result) => result.snapshot != null)) {
    AppToast.showSuccess(context, l10n.batchCancelDone(intent.orderCount));
  }
}

class BatchOrderCancellationStatus extends ConsumerWidget {
  const BatchOrderCancellationStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(orderCancellationProvider.select((s) => s.batch));
    if (batch == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.batchCancelScopeCount(batch.intent.orderCount, batch.intent.symbols.length)),
          SelectableText(batch.intent.address),
          if (batch.currentSymbol case final symbol?) ...[
            const SizedBox(height: 8),
            SelectableText(symbol),
          ],
          if (batch.busy) ...[
            const SizedBox(height: 8),
            OrderCancelProgress(step: batch.step),
            OutlinedButton(
              key: const Key('stop-batch-cancel'),
              onPressed: batch.stopRequested
                  ? null
                  : () => ref.read(orderCancellationProvider.notifier).stopBatch(),
              child: Text(l10n.batchCancelStop),
            ),
          ],
          if (batch.stopRequested) Text(l10n.batchCancelStopped),
          for (final result in batch.results.values)
            Padding(
              key: Key('batch-result-${result.symbol}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(result.symbol, style: Theme.of(context).textTheme.titleSmall),
                  if (batch.busy && batch.currentSymbol == result.symbol)
                    Text(l10n.batchCancelInProgress)
                  else if (!result.submitted)
                    Text(l10n.batchCancelNotSubmitted)
                  else if (result.snapshot case final snapshot?)
                    Text(
                      result.newerOrderEvents
                          ? l10n.orderCancelEventsDuringCheck
                          : snapshot.orders.isEmpty
                          ? l10n.batchCancelNoOpen
                          : l10n.batchCancelRemaining(snapshot.orders.length),
                    ),
                  if (result.failure case final failure?)
                    Text(
                      accountErrorText(context, failure),
                      style: const TextStyle(color: AppColors.negative),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

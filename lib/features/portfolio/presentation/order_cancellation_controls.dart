import '../../../core/errors/error_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/order_cancellation_provider.dart';
import '../domain/aster_open_orders.dart';
import 'order_cancel_progress.dart';

Future<void> confirmOrderCancellation(
  BuildContext context,
  WidgetRef ref,
  AsterOpenOrder order,
) async {
  final controller = ref.read(orderCancellationProvider.notifier);
  final intent = controller.prepare(order);
  if (intent == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l10n.orderCancelTitle),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.orderCancelConfirmHint),
            const SizedBox(height: 12),
            SelectableText(intent.address),
            const SizedBox(height: 8),
            SelectableText(order.symbol),
            SelectableText(order.orderId),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.orderCancelKeep),
          ),
          FilledButton(
            key: const Key('confirm-order-cancel'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.orderCancelConfirm),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) await controller.cancel(intent);
}

class OrderCancellationStatus extends ConsumerWidget {
  const OrderCancellationStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderCancellationProvider);
    final intent = state.intent;
    if (intent == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final failure = state.failure ?? state.result?.failure;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText('${intent.order.symbol} · ${intent.order.orderId}'),
          if (state.busy) ...[const SizedBox(height: 8), OrderCancelProgress(step: state.step)],
          if (state.result case final result?)
            Text(
              result.needsRecheck
                  ? l10n.orderCancelUnknown
                  : result.newerOrderEvents
                  ? l10n.orderCancelEventsDuringCheck
                  : switch (result.resolution!.status) {
                      'CANCELED' => l10n.orderCancelVerified,
                      'FILLED' => l10n.orderCancelFilled,
                      'EXPIRED' => l10n.orderCancelExpired,
                      'REJECTED' => l10n.orderCancelRejected,
                      _ => l10n.orderCancelStillOpen,
                    },
              key: const Key('order-cancel-result'),
            ),
          if (failure != null)
            Text(
              accountErrorText(context, failure),
              style: const TextStyle(color: AppColors.negative),
            ),
          if (state.needsRecheck)
            OutlinedButton(
              key: const Key('recheck-order-cancel'),
              onPressed: state.busy
                  ? null
                  : () => ref.read(orderCancellationProvider.notifier).recheck(),
              child: Text(l10n.orderCancelRecheck),
            ),
        ],
      ),
    );
  }
}

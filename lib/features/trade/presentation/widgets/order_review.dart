import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../application/providers.dart';
import '../../domain/demo_order.dart';
import '../../../market/domain/market.dart';
import 'primitives.dart';

Future<bool?> reviewOrder(BuildContext context, OrderDraft draft) =>
    showAppSheet<bool>(context, _OrderReview(draft: draft));

class _OrderReview extends ConsumerStatefulWidget {
  const _OrderReview({required this.draft});
  final OrderDraft draft;
  @override
  ConsumerState<_OrderReview> createState() => _OrderReviewState();
}

class _OrderReviewState extends ConsumerState<_OrderReview> {
  String? error;
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'review'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            CoinIcon(base: draft.symbol.replaceAll('USDT', '')),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${draft.symbol.replaceAll('USDT', '')} / USDT',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tr(context, draft.buy ? 'long' : 'short'),
              style: TextStyle(color: draft.buy ? AppColors.positive : AppColors.negative),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ValueRow(
          tr(context, 'quantity'),
          '${draft.quantity} ${draft.symbol.replaceAll('USDT', '')}',
        ),
        ValueRow(tr(context, 'price'), '${marketNumber(draft.parsedPrice)} USDT'),
        ValueRow(tr(context, 'orderValue'), '${draft.notional.toStringAsFixed(2)} USDT'),
        ValueRow(tr(context, 'leverage'), '${draft.leverage}×'),
        ValueRow(tr(context, 'margin'), '${draft.margin.toStringAsFixed(2)} USDT'),
        ValueRow(tr(context, 'fees'), '${draft.fee.toStringAsFixed(4)} USDT'),
        const SizedBox(height: 16),
        Text(
          tr(context, 'orderReviewHint'),
          style: const TextStyle(fontSize: 12, color: AppColors.warning),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tr(context, error!), style: const TextStyle(color: AppColors.negative)),
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('confirm-order'),
          onPressed: () {
            final failure = ref.read(accountProvider.notifier).submit(draft);
            if (failure == null) {
              Navigator.pop(context, true);
            } else {
              setState(() => error = failure);
            }
          },
          child: Text(tr(context, 'confirm')),
        ),
      ],
    );
  }
}

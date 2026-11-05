import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/providers.dart';
import '../../domain/demo_order.dart';
import 'primitives.dart';

class PositionsPanel extends ConsumerStatefulWidget {
  const PositionsPanel({super.key});
  @override
  ConsumerState<PositionsPanel> createState() => _PositionsPanelState();
}

class _PositionsPanelState extends ConsumerState<PositionsPanel> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final orders = switch (tab) {
      0 => account.positions,
      1 => account.orders,
      _ => account.history,
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              AppLocalizations.of(context).demoOrdersTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: TabChoices(
              items: [
                '${tr(context, 'positions')} (${account.positions.length})',
                '${tr(context, 'orders')} (${account.orders.length})',
                tr(context, 'history'),
              ],
              selected: tab,
              onSelect: (v) => setState(() => tab = v),
              underlined: true,
            ),
          ),
          const Divider(),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      tab == 0 ? Icons.layers_outlined : Icons.receipt_long_outlined,
                      color: AppColors.muted,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(context, ['noPositions', 'noOrders', 'noHistory'][tab]),
                    style: const TextStyle(color: AppColors.secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    tr(context, 'noPositionsHint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ),
            )
          else
            for (final order in orders) _OrderCard(order: order, tab: tab),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.tab});
  final DemoOrder order;
  final int tab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = order.draft;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${draft.symbol.replaceAll('USDT', '')} / USDT',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(
                '${tr(context, draft.buy ? 'long' : 'short')} ${draft.leverage}×',
                style: TextStyle(
                  fontSize: 11,
                  color: draft.buy ? AppColors.positive : AppColors.negative,
                ),
              ),
              const Spacer(),
              MutedText(tr(context, order.status), size: 10),
            ],
          ),
          const SizedBox(height: 8),
          ValueRow(tr(context, 'size'), '${draft.quantity} ${draft.symbol.replaceAll('USDT', '')}'),
          ValueRow(tr(context, 'entry'), '${draft.price} USDT'),
          SelectableText(order.id, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
          if (tab < 2)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () async {
                  if (tab == 1) {
                    ref.read(accountProvider.notifier).cancel(order.id);
                    message(context, tr(context, 'canceled'));
                    return;
                  }
                  if (ref.read(symbolProvider) != draft.symbol) {
                    ref.read(symbolProvider.notifier).select(draft.symbol);
                    return;
                  }
                  final quote = ref.read(currentMarketProvider);
                  if (quote == null || quote.offline) {
                    message(context, tr(context, 'marketUnavailable'));
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(tr(context, 'close')),
                      content: Text(tr(context, 'orderReviewHint')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(tr(context, 'cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(tr(context, 'close')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(accountProvider.notifier).close(order.id, quote.price);
                    if (context.mounted) message(context, tr(context, 'closed'));
                  }
                },
                child: Text(
                  tr(context, tab == 0 ? 'close' : 'cancel'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }
}

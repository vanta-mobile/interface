import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/application/market_providers.dart';
import '../../application/providers.dart';
import 'primitives.dart';

class ChartMarketStatus extends ConsumerWidget {
  const ChartMarketStatus({super.key, required this.depth});
  final bool depth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncOverviewProvider).value;
    final book = depth ? ref.watch(bookProvider).value : null;
    final loading = !depth && ref.watch(currentMarketProvider) == null;
    final failed = !depth && ref.watch(marketSyncProvider)?.failure != null;
    final historical = depth
        ? false
        : ref.watch(currentMarketProvider.select((market) => market?.offline == true));
    final connected = depth
        ? book?.connected == true
        : sync?.connected == true && !historical && !loading;
    return InkWell(
      key: const Key('chart-market-status'),
      onTap: () => showAppSheet<void>(context, const _MarketDetails()),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: connected ? AppColors.accent : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(context, 'chartSourceShort'),
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
            if (!connected)
              Flexible(
                child: Text(
                  tr(
                    context,
                    failed
                        ? 'marketUnavailable'
                        : loading
                        ? 'loadingChart'
                        : 'offline',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.warning),
                ),
              ),
            const SizedBox(width: 5),
            const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _MarketDetails extends ConsumerWidget {
  const _MarketDetails();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncOverviewProvider).value;
    final last = ref.watch(currentMarketProvider)?.candles.lastOrNull;
    String time(int? timestamp) => timestamp == null || timestamp == 0
        ? '—'
        : DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal().toString().substring(0, 19);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'marketDetails'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        ValueRow(tr(context, 'network'), tr(context, sync?.connected == true ? 'live' : 'offline')),
        ValueRow(tr(context, 'sync'), '${sync?.loaded ?? 0} / ${sync?.total ?? 1}'),
        if (sync != null && sync.repairing > 0)
          ValueRow(tr(context, 'syncing'), '${sync.repairing}'),
        ValueRow(tr(context, 'startTime'), time(last?.time)),
        ValueRow(tr(context, 'eventTime'), time(last?.eventTime)),
        if (last != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              tr(context, last.closed ? 'closedCandle' : 'formingCandle'),
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          tr(context, 'chartHint'),
          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/trading_history_details_provider.dart';
import '../application/trading_history_provider.dart';
import '../domain/trading_history.dart';
import 'portfolio_stats_error.dart';
import 'trading_history_components.dart';
import 'trading_history_order_card.dart';

/// Shown inside the owning session's guarded sheet.
class TradingHistoryRelatedOrders extends ConsumerWidget {
  const TradingHistoryRelatedOrders(this.position, {super.key});
  final HistoryPosition position;

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref
          .refresh(tradingPositionOrdersProvider(position).future)
          .then((_) {}, onError: (Object _) {}),
      ref.refresh(tradingHistoryUnitsProvider.future).then((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(tradingPositionOrdersProvider(position));
    final units = ref.watch(tradingHistoryUnitsProvider).value;
    final orders = state.value;
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          key: const Key('history-related-orders'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HistorySheetHeader(l.tradingHistoryRelatedOrders),
              const SizedBox(height: 16),
              if (orders == null && state.isLoading)
                const SkeletonBox(height: 140)
              else if (state.hasError)
                StatusFailureView(
                  message: portfolioStatsErrorText(context, state.error!),
                  retrying: state.isLoading,
                  onRetry: () => _refresh(ref),
                ),
              if (orders != null) ...[
                if (orders.isEmpty) StatusEmptyView(message: l.historyEmpty),
                for (final order in orders)
                  TradingHistoryOrderCard(
                    key: ValueKey(order.key),
                    order: order,
                    units: units?[order.symbol],
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

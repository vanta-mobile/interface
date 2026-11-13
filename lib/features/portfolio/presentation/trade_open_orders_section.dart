import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/open_orders_provider.dart';
import '../application/order_cancellation_provider.dart';
import '../application/position_risk_provider.dart';
import '../../../core/errors/error_text.dart';
import '../application/open_order_strategies_provider.dart';
import '../application/open_orders_auto_read_provider.dart';
import '../application/order_modification_provider.dart';
import '../domain/order_modification.dart';
import 'open_order_edit_sheet.dart';
import 'aster_open_order_card.dart';
import 'batch_order_cancellation_controls.dart';
import 'order_cancellation_controls.dart';
import 'trade_check_option.dart';
import '../domain/aster_open_orders.dart';
import '../domain/position_risk.dart';

/// Open-orders tab beneath the Futures trade workspace.
class TradeOpenOrdersSection extends ConsumerStatefulWidget {
  const TradeOpenOrdersSection({super.key});
  @override
  ConsumerState<TradeOpenOrdersSection> createState() => _TradeOpenOrdersSectionState();
}

class _TradeOpenOrdersSectionState extends ConsumerState<TradeOpenOrdersSection> {
  bool currentSymbolOnly = false;

  /// Keeps the failure state (with its spinning Retry) in place while the
  /// retried read runs; the controller clears the failure when a read starts.
  AccountReadFailure? retrying;

  Future<void> retry() async {
    setState(() => retrying = ref.read(openOrdersReadProvider).failure);
    try {
      await ref.read(openOrdersReadProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => retrying = null);
    }
  }

  /// Shows the order's market at the top of the trade page, switching symbol
  /// first when the order belongs to another market.
  void openMarket(String orderSymbol) {
    final symbol = ref.read(symbolProvider);
    if (orderSymbol != symbol) ref.read(symbolProvider.notifier).select(orderSymbol);
    Scrollable.maybeOf(context)?.position
        .animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(openOrdersAutoReadProvider);
    final state = ref.watch(openOrdersReadProvider);
    final cancellation = ref.watch(orderCancellationProvider);
    final session = ref.watch(authProvider);
    final strategies = ref.watch(openOrderStrategiesProvider);
    final positions = ref.watch(positionRiskProvider.select((s) => s.account?.positions));
    final modifying = ref.watch(orderModificationProvider.select((s) => s.busy));
    final canCancel =
        session.identity?.signingAvailable == true &&
        !session.busy &&
        !state.busy &&
        !cancellation.busy &&
        !cancellation.needsRecheck &&
        !modifying;
    final symbol = ref.watch<String>(symbolProvider);
    final all = state.account?.orders;
    final orders = all?.where((order) => !currentSymbolOnly || order.symbol == symbol).toList();
    int? leverage(String orderSymbol, String side) {
      for (final position in positions ?? const <PositionRisk>[]) {
        if (position.symbol == orderSymbol && position.side == side) return position.leverage;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TradeCheckOption(
                label: l10n.openOrdersCurrentSymbol,
                tapKey: const Key('open-orders-current-symbol'),
                value: currentSymbolOnly,
                onChanged: (value) => setState(() => currentSymbolOnly = value),
              ),
            ),
            TextButton(
              key: const Key('cancel-all-open-orders'),
              onPressed: canCancel && orders?.isNotEmpty == true
                  ? () => confirmBatchCancellation(
                      context,
                      ref,
                      symbol: currentSymbolOnly ? symbol : null,
                    )
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: TradeColors.negative,
                disabledForegroundColor: TradeColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(44, 44),
                textStyle: TradeTypography.body,
              ),
              child: Text(l10n.openOrdersCancelAll),
            ),
          ],
        ),
        if ((all == null ? state.failure ?? retrying : null) case final failure?)
          StatusFailureView(
            message: accountErrorText(context, failure),
            retrying: state.busy,
            onRetry: retry,
          )
        else if (state.failure case final failure?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              accountErrorText(context, failure),
              key: const Key('open-orders-read-error'),
              style: TradeTypography.body.copyWith(color: TradeColors.negative),
            ),
          )
        else if (all == null && state.busy)
          const Padding(
            key: Key('open-orders-skeleton'),
            padding: EdgeInsets.only(top: 16),
            child: SkeletonBox(height: 220, radius: 20),
          ),
        const OrderCancellationStatus(),
        const BatchOrderCancellationStatus(),
        if (orders != null && orders.isEmpty)
          StatusEmptyView(
            key: const Key('open-orders-empty'),
            message: currentSymbolOnly && all!.isNotEmpty
                ? l10n.openOrdersNoCurrentSymbol
                : l10n.openOrdersEmpty,
          ),
        for (final order in orders ?? const <AsterOpenOrder>[])
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AsterOpenOrderCard(
              order: order,
              leverage: leverage(order.symbol, order.positionSide),
              strategy: strategies[OpenOrderStrategiesController.key(order)],
              onCancel: canCancel ? () => confirmOrderCancellation(context, ref, order) : null,
              editable: canModifyOpenOrder(
                order,
                strategy: strategies[OpenOrderStrategiesController.key(order)],
              ),
              onEdit: canCancel ? () => showOpenOrderEditSheet(context, order) : null,
              onViewChart: order.symbol == symbol
                  ? null
                  : () => ref.read(symbolProvider.notifier).select(order.symbol),
              onTap: () => openMarket(order.symbol),
            ),
          ),
      ],
    );
  }
}

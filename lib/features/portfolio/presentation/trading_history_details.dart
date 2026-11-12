import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/trading_history_access_provider.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/trading_history_details_provider.dart';
import '../application/trading_history_provider.dart';
import '../domain/aster_account.dart';
import '../domain/trading_history.dart';
import 'mode_settings_sheet.dart';
import 'portfolio_components.dart';
import 'portfolio_stats_error.dart';
import 'trading_history_components.dart';

Future<void> showTradingOrderDetails(
  BuildContext context,
  HistoryOrder order,
  AsterContractUnits? units,
) => _show(
  context,
  TradingHistoryTab.orders,
  (address, owner) => _OrderDetails(order: order, units: units, address: address, owner: owner),
);
Future<void> showHistoryRelatedOrders(BuildContext context, HistoryPosition position) => _show(
  context,
  TradingHistoryTab.positions,
  (address, owner) => _SessionSheet(
    tab: TradingHistoryTab.positions,
    owner: owner,
    address: address,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HistorySheetHeader(AppLocalizations.of(context).tradingHistoryRelatedOrders),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).tradingHistoryRelatedUnavailable,
              style: TradeTypography.body,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _show(
  BuildContext context,
  TradingHistoryTab tab,
  Widget Function(String?, Object) builder,
) async {
  final container = ProviderScope.containerOf(context);
  final address = container.read(tradingHistoryAccessProvider(tab)).address;
  final owner = container.read(tradingHistoryIdentityProvider);
  await showModeSettingsSheet<void>(context, builder(address, owner));
}

/// All private details disappear as soon as the owning session changes.
class _SessionSheet extends ConsumerWidget {
  const _SessionSheet({
    required this.address,
    required this.child,
    required this.owner,
    required this.tab,
  });
  final Object owner;
  final TradingHistoryTab tab;
  final String? address;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(tradingHistoryAccessProvider(tab));
    if (session.address != address ||
        !session.ready ||
        ref.watch(tradingHistoryIdentityProvider) != owner) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HistorySheetHeader(
            historyUsesAster(tab)
                ? AppLocalizations.of(context).enableTradingTitle
                : AppLocalizations.of(context).vantaApiSignInTitle,
          ),
        ),
      );
    }
    return child;
  }
}

class _OrderDetails extends ConsumerWidget {
  const _OrderDetails({
    required this.order,
    required this.address,
    required this.owner,
    this.units,
  });
  final Object owner;
  final HistoryOrder order;
  final String? address;
  final AsterContractUnits? units;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(tradingHistoryAccessProvider(TradingHistoryTab.orders));
    if (!session.ready ||
        session.address != address ||
        ref.watch(tradingHistoryIdentityProvider) != owner) {
      return _SessionSheet(
        address: address,
        owner: owner,
        tab: TradingHistoryTab.orders,
        child: const SizedBox(),
      );
    }
    final l = AppLocalizations.of(context), r = order;
    final state = ref.watch(tradingOrderDetailsProvider(order));
    final data = state.value;
    final currentUnits = ref.watch(tradingHistoryUnitsProvider).value?[r.symbol] ?? units;
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref
                .refresh(tradingOrderDetailsProvider(order).future)
                .then((_) {}, onError: (Object _) {}),
            ref.refresh(tradingHistoryUnitsProvider.future).then((_) {}, onError: (Object _) {}),
          ]);
        },
        child: SingleChildScrollView(
          key: const Key('history-order-details'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HistorySheetHeader(l.tradingHistoryOrderDetails),
              const SizedBox(height: 8),
              const Divider(height: 1, color: TradeColors.line),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SelectableText(r.symbol, style: TradeTypography.symbol),
                  HistoryStatus(r.status),
                ],
              ),
              const SizedBox(height: 12),
              HistoryRow(
                l.tradingHistoryFilledTotal,
                '${historyAmount(r.filledValue, fixed: 2)} / ${historyUnit(r.orderValue, currentUnits?.quote, fixed: 2)}',
              ),
              HistoryRow(l.tradingHistoryFee, historyUnit(data?.fee, data?.feeAsset)),
              HistoryRow(
                l.tradingHistoryRealizedProfit,
                historyUnit(data?.realizedPnl, currentUnits?.margin, fixed: 2),
              ),
              HistoryRow(l.tradingHistoryUpdatedAt, historyTime(r.updatedAt)),
              HistoryRow(l.orderId, r.id, copyable: true),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: TradeColors.line),
              ),
              Text(l.tradingHistoryTradeDetails, style: TradeTypography.symbol),
              const SizedBox(height: 16),
              if (data == null && state.isLoading)
                const SkeletonBox(height: 174, radius: 12)
              else if (state.hasError)
                StatusFailureView(
                  message: portfolioStatsErrorText(context, state.error!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  retrying: state.isLoading,
                  onRetry: () async {
                    await ref.refresh(tradingOrderDetailsProvider(order).future).then((_) {});
                  },
                ),
              if (data != null) ...[
                if (!data.complete)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l.tradingHistoryIncompleteFills,
                      style: TradeTypography.body.copyWith(color: TradeColors.muted),
                    ),
                  ),
                if (data.fills.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      data.complete ? l.tradingHistoryNoTrades : l.tradingHistoryFillsUnavailable,
                      textAlign: TextAlign.center,
                      style: TradeTypography.body.copyWith(color: TradeColors.muted),
                    ),
                  ),
                for (final fill in data.fills)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PortfolioCard(
                      radius: 12,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          HistoryRow(l.tradingHistoryDate, historyTime(fill.time)),
                          HistoryRow(
                            l.tradingHistoryQuantity,
                            historyUnit(fill.quantity, currentUnits?.base),
                          ),
                          HistoryRow(
                            l.price,
                            historyUnit(fill.price, currentUnits?.quote, fixed: 6),
                          ),
                          HistoryRow(
                            l.tradingHistoryRealizedPnl,
                            historyUnit(fill.realizedPnl, currentUnits?.margin, fixed: 2),
                          ),
                          // Aster commission is signed; display the cost of a charge.
                          HistoryRow(l.tradingHistoryFee, historyUnit(-fill.fee, fill.feeAsset)),
                          HistoryRow(l.tradingHistoryRole, historyRole(l, fill.maker)),
                          HistoryRow(l.historyTradeId, fill.id, copyable: true),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

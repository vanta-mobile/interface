import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../../trade/application/providers.dart' show symbolProvider;
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/trading_history_provider.dart';
import '../application/trading_history_access_provider.dart';
import '../domain/aster_account.dart';
import '../domain/trading_history.dart';
import 'portfolio_stats_error.dart';
import 'trade_check_option.dart';
import 'trading_history_fill_card.dart';
import 'trading_history_order_card.dart';
import 'trading_history_position_card.dart';
import 'trading_history_transaction_row.dart';

class TradingHistoryResults extends ConsumerStatefulWidget {
  const TradingHistoryResults({super.key, required this.tab});
  final TradingHistoryTab tab;
  @override
  ConsumerState<TradingHistoryResults> createState() => _TradingHistoryResultsState();
}

class _TradingHistoryResultsState extends ConsumerState<TradingHistoryResults> {
  bool filtered = false;
  Future<void> retry() async {
    if (ref.read(authProvider).identity?.walletAddress == null) {
      showAccountSheet(context);
      return;
    }
    if (historyUsesAster(widget.tab) && !ref.read(tradingHistoryAccessProvider(widget.tab)).ready) {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const EnableTradingScreen()));
    } else if (!historyUsesAster(widget.tab) && !ref.read(vantaApiSessionProvider).ready) {
      await ref.read(vantaApiSessionProvider.notifier).ensure();
    }
    if (mounted) await refresh();
  }

  Future<void> refresh() async {
    if (!mounted || !ref.read(tradingHistoryAccessProvider(widget.tab)).ready) return;
    final provider = tradingHistoryProvider(widget.tab);
    await Future.wait([
      ref.read(provider.notifier).refresh(),
      ref.refresh(tradingHistoryUnitsProvider.future).then((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tab = widget.tab;
    final session = ref.watch(tradingHistoryAccessProvider(tab));
    final state = ref.watch(tradingHistoryProvider(tab));
    final unitsState = ref.watch(tradingHistoryUnitsProvider);
    final units = unitsState.value ?? const <String, AsterContractUnits>{};
    final symbol = ref.watch(symbolProvider);
    // Riverpod may retain old data during dependency rebuilds; scope it here.
    final page = session.ready && state.page?.address == session.address ? state.page : null;
    final all = page?.records ?? const <TradingHistoryRecord>[];
    final records = all
        .where(
          (r) =>
              !filtered ||
              (tab == TradingHistoryTab.orders
                  ? r is! HistoryOrder || r.status != 'CANCELED'
                  : r.symbol == symbol),
        )
        .toList();
    final blocked = !session.ready && !session.pending;
    final failure = state.error ?? session.failure;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        key: const Key('futures-history-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (tab != TradingHistoryTab.transactions)
            TradeCheckOption(
              tapKey: const Key('history-filter'),
              value: filtered,
              label: tab == TradingHistoryTab.orders
                  ? l.tradingHistoryHideCanceled
                  : l.openOrdersCurrentSymbol,
              onChanged: (value) => setState(() => filtered = value),
            ),
          if (page == null && (state.busy && session.ready || session.pending)) ...[
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SkeletonBox(height: 150, radius: 20),
              ),
          ] else if (page == null && (blocked || failure != null))
            StatusFailureView(
              key: const Key('history-failure'),
              title: blocked
                  ? session.unavailable
                        ? l.vantaApiUnavailableTitle
                        : historyUsesAster(tab)
                        ? l.enableTradingTitle
                        : l.vantaApiSignInTitle
                  : null,
              message: failure != null
                  ? portfolioStatsErrorText(context, failure)
                  : session.unavailable
                  ? l.vantaApiUnavailable
                  : historyUsesAster(tab)
                  ? l.accountSignInToRead
                  : l.vantaApiSignIn,
              retryLabel: blocked
                  ? historyUsesAster(tab)
                        ? l.enableTradingTitle
                        : l.vantaApiSignInAction
                  : null,
              onRetry: session.unavailable ? null : retry,
            ),
          if (page != null) ...[
            if (page.recentDays case final days?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.tradingHistoryRecentDays(days),
                  style: TradeTypography.body.copyWith(color: TradeColors.muted),
                ),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  portfolioStatsErrorText(context, state.error!),
                  style: TradeTypography.body.copyWith(color: TradeColors.negative),
                ),
              ),
            if (page.partial)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.tradingHistoryPartial,
                  style: TradeTypography.body.copyWith(color: TradeColors.muted),
                ),
              ),
            if (records.isEmpty)
              StatusEmptyView(key: const Key('futures-history-empty'), message: l.historyEmpty),
            for (final r in records)
              Padding(
                key: ValueKey(r.key),
                padding: EdgeInsets.only(
                  top: tab == TradingHistoryTab.orders || tab == TradingHistoryTab.transactions
                      ? 0
                      : 12,
                ),
                child: switch (r) {
                  HistoryOrder() => TradingHistoryOrderCard(order: r, units: units[r.symbol]),
                  HistoryPosition() => TradingHistoryPositionCard(
                    position: r,
                    units: units[r.symbol],
                  ),
                  HistoryFill() => TradingHistoryFillCard(fill: r, units: units[r.symbol]),
                  HistoryTransaction() => TradingHistoryTransactionRow(transaction: r),
                },
              ),
            if (page.next != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: StatusActionButton(
                  key: const Key('history-load-more'),
                  label: l.historyContinue,
                  loading: state.busy,
                  onPressed: () => ref.read(tradingHistoryProvider(tab).notifier).loadMore(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

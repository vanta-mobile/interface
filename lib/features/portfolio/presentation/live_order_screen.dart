import 'embedded_order_feedback.dart';
import '../application/main_order_capacity_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/main_order_refresh_provider.dart';
import '../application/order_entry_gate_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../application/live_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order_entry_mode.dart';
import 'live_order_form.dart';
import 'live_order_mode_selector.dart';
import 'live_order_status.dart';
import 'scaled_order_screen.dart';
import '../../trade/presentation/widgets/trade_order_pending.dart';
import '../../trade/presentation/widgets/trade_account_settings.dart';
import '../../trade/application/providers.dart' show orderPriceProvider, symbolProvider;
import '../domain/live_order.dart';

class LiveOrderScreen extends ConsumerStatefulWidget {
  const LiveOrderScreen({super.key, required this.symbol});
  final String symbol;
  @override
  ConsumerState<LiveOrderScreen> createState() => _LiveOrderScreenState();
}

class _LiveOrderScreenState extends ConsumerState<LiveOrderScreen> {
  LiveOrderEntryMode mode = LiveOrderEntryMode.limit;
  String get symbol => widget.symbol;

  @override
  void didUpdateWidget(covariant LiveOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != symbol) mode = LiveOrderEntryMode.limit;
  }

  void _selectMode(LiveOrderEntryMode next) {
    if (!mounted) return;
    final live = ref.read(liveOrderProvider), activity = ref.read(symbolSettingsActivityProvider);
    final background = ref.read(mainOrderRefreshProvider).background;
    if ((!background && (ref.read(mainOrderRefreshProvider).loading || live.busy)) ||
        live.intent != null && live.busy ||
        !background && activity.owner != null ||
        activity.recoveryBlocked ||
        ref.read(authProvider).busy) {
      return;
    }
    if (!next.inline && next != LiveOrderEntryMode.scaled) return;
    if (next.inline) setState(() => mode = next);
    if (next == LiveOrderEntryMode.scaled) openScaledOrder(context, symbol);
  }

  Future<void> _refresh() => ref.read(mainOrderRefreshProvider.notifier).refresh(symbol);

  /// Kept alive while hidden so in-progress input survives reads and failures.
  Widget _orderForm(LiveOrderContext data, {required bool visible}) => Visibility(
    key: ValueKey(('order-form-section', data.address, data.symbol)),
    visible: visible,
    maintainState: true,
    child: LiveOrderForm(
      key: ValueKey((data.address, data.symbol)),
      data: data,
      mode: mode,
      onModeChanged: (next) => setState(() => mode = next),
    ),
  );

  /// Symbol changes clear a book-selected price; identity changes reset the
  /// entry mode so another wallet never inherits it.
  void _listenSelection() {
    ref.listen(symbolProvider, (previous, next) {
      if (previous != next) {
        ref.read(orderPriceProvider.notifier).setPrice('');
      }
    });
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (previous, next) {
        if (previous != next) setState(() => mode = LiveOrderEntryMode.limit);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _listenSelection();
    final state = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider);
    final settings = ref.watch(symbolSettingsActivityProvider);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final gate = ref.watch(orderEntryGateProvider);
    final data = state.context?.symbol == symbol && gate == OrderEntryGate.ready
        ? state.context
        : null;
    final capacity = ref.watch(mainOrderCapacityProvider);
    final reading = refresh.loading || (state.busy && state.intent == null) || capacity.loading;
    final readFailure = gate == OrderEntryGate.ready && state.intent == null
        ? refresh.failure ?? state.failure ?? data?.fundsFailure ?? capacity.failure
        : null;
    final failed = readFailure != null && data == null;
    return Column(
      key: const Key('trade-live-order'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TradeAccountSettings(
          symbol: symbol,
          data: data,
          enabled:
              !refresh.loading &&
              !state.busy &&
              !auth.busy &&
              !settings.busy &&
              settings.owner == null &&
              !settings.recoveryBlocked,
        ),
        const SizedBox(height: 8),
        LiveOrderModeSelector(
          selected: mode,
          enabled:
              (!refresh.loading || refresh.background) &&
              (!state.busy || refresh.background && state.intent == null) &&
              (settings.owner == null || refresh.background) &&
              !settings.recoveryBlocked &&
              !auth.busy,
          onSelected: _selectMode,
        ),
        if (data != null) ...[
          const SizedBox(height: 16),
          _orderForm(data, visible: !failed),
        ] else if (!failed)
          TradeOrderPending(
            symbol: symbol,
            market: mode.marketExecution,
            loading: reading && gate == OrderEntryGate.ready,
          ),
        if (failed) EmbeddedOrderFailure(failure: readFailure, retry: _refresh, loading: reading),
        const LiveOrderStatus(),
      ],
    );
  }
}

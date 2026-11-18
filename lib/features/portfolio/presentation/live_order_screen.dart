import 'embedded_order_feedback.dart';
import '../application/main_order_capacity_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/main_order_refresh_provider.dart';
import '../application/order_entry_gate_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../application/live_order_provider.dart';
import '../domain/live_order_entry_mode.dart';
import 'hedge_intent_switch.dart';
import 'live_order_form.dart';
import 'live_order_mode_selector.dart';
import 'scaled_order_embedded.dart';
import '../../trade/presentation/widgets/trade_order_pending.dart';
import '../../trade/presentation/widgets/trade_account_settings.dart';
import '../../trade/application/providers.dart' show orderPriceProvider, symbolProvider;
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';

class LiveOrderScreen extends ConsumerStatefulWidget {
  const LiveOrderScreen({super.key, required this.symbol});
  final String symbol;
  @override
  ConsumerState<LiveOrderScreen> createState() => _LiveOrderScreenState();
}

class _LiveOrderScreenState extends ConsumerState<LiveOrderScreen> {
  LiveOrderEntryMode mode = LiveOrderEntryMode.limit;

  /// The ordinary form keeps its last inline type while Scaled Order shows.
  LiveOrderEntryMode inlineMode = LiveOrderEntryMode.limit;

  /// Hedge mode only: the Close segment reduces the LONG/SHORT position.
  bool closing = false;
  String get symbol => widget.symbol;

  @override
  void didUpdateWidget(covariant LiveOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != symbol) {
      mode = inlineMode = LiveOrderEntryMode.limit;
      closing = false;
    }
  }

  void _selectMode(LiveOrderEntryMode next) {
    if (!mounted) return;
    final live = ref.read(liveOrderProvider);
    final background = ref.read(mainOrderRefreshProvider).background;
    if ((!background && (ref.read(mainOrderRefreshProvider).loading || live.busy)) ||
        live.intent != null && live.busy ||
        ref.read(authProvider).busy) {
      return;
    }
    if (!next.inline && next != LiveOrderEntryMode.scaled) return;
    setState(() {
      mode = next;
      if (next.inline) inlineMode = next;
    });
  }

  Future<void> _refresh() => ref.read(mainOrderRefreshProvider.notifier).refresh(symbol);

  /// Kept alive while hidden so in-progress input survives reads, failures
  /// and a visit to Scaled Order.
  Widget _orderForm(LiveOrderContext data, {required bool visible}) {
    final scaled = mode == LiveOrderEntryMode.scaled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Visibility(
          key: ValueKey(('order-form-section', data.address, data.symbol)),
          visible: visible && !scaled,
          maintainState: true,
          child: LiveOrderForm(
            key: ValueKey((data.address, data.symbol)),
            data: data,
            mode: inlineMode,
            closing: closing,
            onModeChanged: (next) => setState(() => mode = inlineMode = next),
          ),
        ),
        if (scaled && visible)
          ScaledOrderEmbeddedForm(
            key: ValueKey(('scaled-order', data.address, data.symbol)),
            data: data,
            enabled: !ref.watch(authProvider).busy,
          ),
      ],
    );
  }

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
        if (previous != next) {
          setState(() {
            mode = inlineMode = LiveOrderEntryMode.limit;
            closing = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _listenSelection();
    final state = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider);
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
    final failed = readFailure != null && (data == null || readFailure.requiresAuthorization);
    final settingsEnabled =
        (!refresh.loading || refresh.background) &&
        (!state.busy || refresh.background && state.intent == null) &&
        !auth.busy;
    return Column(
      key: const Key('trade-live-order'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data?.mode == FuturesPositionMode.hedge) ...[
          HedgeIntentSwitch(
            closing: closing,
            onChanged: settingsEnabled ? (value) => setState(() => closing = value) : null,
          ),
          const SizedBox(height: 8),
        ],
        TradeAccountSettings(
          symbol: symbol,
          data: data,
          // A periodic background refresh must not lock the settings; opening
          // one stops that refresh first (see [TradeAccountSettings]).
          enabled:
              (!refresh.loading || refresh.background) &&
              (!state.busy || refresh.background && state.intent == null) &&
              !auth.busy,
        ),
        const SizedBox(height: 8),
        LiveOrderModeSelector(
          selected: mode,
          enabled:
              (!refresh.loading || refresh.background) &&
              (!state.busy || refresh.background && state.intent == null) &&
              !auth.busy,
          onSelected: _selectMode,
        ),
        // The form and the pending form each start with the design's 8px gap.
        if (data != null)
          _orderForm(data, visible: !failed)
        else if (!failed)
          TradeOrderPending(
            symbol: symbol,
            market: mode.marketExecution,
            loading: reading && gate == OrderEntryGate.ready,
          ),
        if (failed) EmbeddedOrderFailure(failure: readFailure, retry: _refresh, loading: reading),
      ],
    );
  }
}

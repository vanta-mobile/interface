import '../../../core/errors/error_text.dart';
import 'order_recovery_notice.dart';
import 'embedded_order_feedback.dart';
import '../application/main_order_capacity_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/order_entry_gate_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order_entry_mode.dart';
import '../domain/position_margin_mode.dart';
import 'live_order_form.dart';
import 'live_order_mode_selector.dart';
import 'live_order_status.dart';
import 'scaled_order_screen.dart';
import '../../trade/presentation/widgets/trade_order_pending.dart';
import '../../trade/presentation/widgets/trade_account_settings.dart';
import '../../trade/application/providers.dart' show orderPriceProvider, symbolProvider;
import '../../auth/domain/auth_session.dart';
import '../domain/live_order.dart';

part 'live_order_screen_standalone.dart';

void openLiveOrder(BuildContext context, String symbol) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => LiveOrderScreen(symbol: symbol)));

void openLiveClose(BuildContext context, String symbol, String side, {bool market = true}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            LiveOrderScreen(symbol: symbol, closingSide: side, initialCloseMarket: market),
      ),
    );

void openPositionTriggers(BuildContext context, String symbol, String side) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            LiveOrderScreen(symbol: symbol, closingSide: side, initialConditional: true),
      ),
    );

class LiveOrderScreen extends ConsumerStatefulWidget {
  const LiveOrderScreen({
    super.key,
    required this.symbol,
    this.closingSide,
    this.initialConditional = false,
    this.initialCloseMarket = true,
    this.embedded = false,
  });
  final String symbol;
  final String? closingSide;
  final bool initialConditional;
  final bool initialCloseMarket;
  final bool embedded;
  @override
  ConsumerState<LiveOrderScreen> createState() => _LiveOrderScreenState();
}

class _LiveOrderScreenState extends ConsumerState<LiveOrderScreen> {
  LiveOrderEntryMode mode = LiveOrderEntryMode.limit;
  LiveOrderEntryMode remembered = LiveOrderEntryMode.stopLimit;
  String get symbol => widget.symbol;
  String? get closingSide => widget.closingSide;
  bool get initialConditional => widget.initialConditional;

  @override
  void didUpdateWidget(covariant LiveOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != symbol) {
      mode = LiveOrderEntryMode.limit;
      remembered = LiveOrderEntryMode.stopLimit;
    }
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
    setState(() {
      if (next != LiveOrderEntryMode.limit && next != LiveOrderEntryMode.market) remembered = next;
      if (next.inline) mode = next;
    });
    if (next == LiveOrderEntryMode.scaled) openScaledOrder(context, symbol);
  }

  Future<void> _refresh() async {
    if (closingSide == null) {
      await ref.read(mainOrderRefreshProvider.notifier).refresh(symbol);
    } else {
      await ref.read(liveOrderProvider.notifier).load(symbol, includeFunds: false);
    }
  }

  /// Kept alive while hidden so in-progress input survives reads and failures.
  Widget _orderForm(LiveOrderContext data, {required bool visible}) => Visibility(
    key: ValueKey((
      'order-form-section',
      data.address,
      data.symbol,
      closingSide,
      initialConditional,
    )),
    visible: visible,
    maintainState: true,
    child: LiveOrderForm(
      key: ValueKey((data.address, data.symbol, closingSide, initialConditional)),
      data: data,
      closingSide: closingSide,
      initialConditional: initialConditional,
      initialCloseMarket: widget.initialCloseMarket,
      mode: closingSide == null && !initialConditional ? mode : null,
      bookPricing: widget.embedded,
      embedded: widget.embedded,
      onModeChanged: (next) {
        setState(() {
          mode = next;
          if (next != LiveOrderEntryMode.limit && next != LiveOrderEntryMode.market) {
            remembered = next;
          }
        });
      },
    ),
  );

  /// Symbol changes clear a book-selected price; identity changes reset the
  /// remembered entry modes so another wallet never inherits them.
  void _listenSelection() {
    ref.listen(symbolProvider, (previous, next) {
      if (widget.embedded && previous != next) {
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
            mode = LiveOrderEntryMode.limit;
            remembered = LiveOrderEntryMode.stopLimit;
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
    final settings = ref.watch(symbolSettingsActivityProvider);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final gate = ref.watch(orderEntryGateProvider);
    final data =
        state.context?.symbol == symbol && (!widget.embedded || gate == OrderEntryGate.ready)
        ? state.context
        : null;
    final capacity = ref.watch(mainOrderCapacityProvider);
    final reading = refresh.loading || (state.busy && state.intent == null) || capacity.loading;
    final readFailure = gate == OrderEntryGate.ready && state.intent == null
        ? refresh.failure ?? state.failure ?? data?.fundsFailure ?? capacity.failure
        : null;
    final failed = widget.embedded && readFailure != null && data == null;
    final children = <Widget>[
      const OrderRecoveryNotice(showOrders: false),
      if (widget.embedded) ...[
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
      ],
      if (closingSide == null && !initialConditional)
        LiveOrderModeSelector(
          selected: mode,
          remembered: remembered,
          enabled:
              (!refresh.loading || refresh.background) &&
              (!state.busy || refresh.background && state.intent == null) &&
              (settings.owner == null || refresh.background) &&
              !settings.recoveryBlocked &&
              !auth.busy,
          onSelected: _selectMode,
          compact: widget.embedded,
        ),
      if (!widget.embedded)
        ..._standaloneHeader(state: state, auth: auth, settings: settings, refresh: refresh),
      if (data != null) ...[
        const SizedBox(height: 16),
        if (!widget.embedded) ..._contextSummary(data, stale: state.stale && !refresh.loading),
        _orderForm(data, visible: !failed),
      ] else if (widget.embedded && !failed)
        TradeOrderPending(
          symbol: symbol,
          market: mode.marketExecution,
          loading: reading && gate == OrderEntryGate.ready,
        ),
      if (failed) EmbeddedOrderFailure(failure: readFailure, retry: _refresh, loading: reading),
      LiveOrderStatus(compact: widget.embedded),
    ];
    if (widget.embedded) {
      return Column(
        key: const Key('trade-live-order'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return _standalonePage(children);
  }
}

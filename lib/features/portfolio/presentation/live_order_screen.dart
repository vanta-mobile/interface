import '../../../core/errors/error_text.dart';
import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../application/main_order_refresh_provider.dart';
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
    if (ref.read(mainOrderRefreshProvider).loading ||
        live.busy ||
        live.needsRecheck ||
        activity.owner != null ||
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

  @override
  Widget build(BuildContext context) {
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
    final l10n = AppLocalizations.of(context), state = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider), identity = auth.identity;
    final settings = ref.watch(symbolSettingsActivityProvider);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final data = state.context?.symbol == symbol ? state.context : null;
    final children = <Widget>[
      const OrderRecoveryNotice(),
      if (widget.embedded) ...[
        TradeAccountSettings(
          symbol: symbol,
          data: data,
          enabled:
              !refresh.loading &&
              !state.busy &&
              !state.needsRecheck &&
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
              !refresh.loading &&
              !state.busy &&
              !state.needsRecheck &&
              settings.owner == null &&
              !settings.recoveryBlocked &&
              !auth.busy,
          onSelected: _selectMode,
          compact: widget.embedded,
        ),
      if (!widget.embedded) ...[
        SelectableText(symbol, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(closingSide == null ? l10n.liveOrderScope : l10n.liveCloseScope),
        if (closingSide != null) SelectableText(closingSide!),
        const SizedBox(height: 12),
        if (identity?.walletAddress case final address?) SelectableText(address),
      ],
      FilledButton.icon(
        key: const Key('live-order-read'),
        onPressed:
            refresh.loading ||
                state.busy ||
                state.needsRecheck ||
                settings.owner != null ||
                auth.busy
            ? null
            : identity?.signingAvailable == true && identity?.walletAddress != null
            ? _refresh
            : () => showAccountSheet(context),
        icon: refresh.loading
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
        label: Text(
          identity == null
              ? l10n.accountSignInToRead
              : identity.walletAddress == null
              ? l10n.createWallet
              : !identity.signingAvailable
              ? l10n.reconnectExternalWallet
              : closingSide == null
              ? l10n.liveCapacityRefreshAccount
              : l10n.liveOrderReadContext,
        ),
      ),
      if (!widget.embedded)
        Text(
          closingSide == null ? l10n.liveCapacityRefreshAccountHint : l10n.liveOrderReadHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (refresh.loading)
        TextButton(
          key: const Key('live-order-read-stop'),
          onPressed: ref.read(mainOrderRefreshProvider.notifier).stop,
          child: Text(l10n.cancel),
        ),
      if (refresh.failure case final failure?)
        Text(
          accountErrorText(context, failure),
          key: const Key('live-order-refresh-error'),
          style: const TextStyle(color: AppColors.negative),
        ),
      if (settings.owner != null && settings.owner != SymbolSetting.order)
        Text(l10n.liveOrderSettingsBusy, style: const TextStyle(color: AppColors.warning)),
      if (state.busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
      if (data != null) ...[
        const SizedBox(height: 16),
        if (!widget.embedded) ...[
          ValueRow(l10n.liveOrderMarkPrice, data.markPrice.toString()),
          ValueRow(l10n.leverageCurrentSetting, '${data.leverage}×'),
          ValueRow(
            l10n.accountMarginMode,
            data.marginMode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode,
          ),
          ValueRow(
            l10n.positionModeSettings,
            data.mode == FuturesPositionMode.oneWay
                ? l10n.positionModeOneWay
                : l10n.positionModeHedge,
          ),
        ],
        if (state.stale)
          Text(l10n.liveOrderContextExpired, style: const TextStyle(color: AppColors.warning)),
        LiveOrderForm(
          key: ValueKey((data.address, data.symbol, closingSide, initialConditional)),
          data: data,
          closingSide: closingSide,
          initialConditional: initialConditional,
          initialCloseMarket: widget.initialCloseMarket,
          mode: closingSide == null && !initialConditional ? mode : null,
          bookPricing: widget.embedded,
          onModeChanged: (next) {
            setState(() {
              mode = next;
              if (next != LiveOrderEntryMode.limit && next != LiveOrderEntryMode.market) {
                remembered = next;
              }
            });
          },
        ),
      ] else if (widget.embedded)
        TradeOrderPending(symbol: symbol, market: mode.marketExecution),
      const LiveOrderStatus(),
    ];
    if (widget.embedded) {
      // Account reads belong after the order controls for every identity.
      // Keep this explicit action without interrupting the compact field stack.
      final readIndex = children.indexWhere((child) => child.key == const Key('live-order-read'));
      final readButton = children.removeAt(readIndex);
      children.insert(
        children.length - 1,
        Padding(padding: const EdgeInsets.only(top: 8), child: readButton),
      );
      return Column(
        key: const Key('trade-live-order'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          initialConditional
              ? l10n.liveOrderPositionTriggers
              : closingSide == null
              ? l10n.liveOrderTitle
              : l10n.liveCloseTitle,
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const Key('live-order-page'),
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ),
    );
  }
}

import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
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

void openLiveOrder(BuildContext context, String symbol) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => LiveOrderScreen(symbol: symbol)));

void openLiveClose(BuildContext context, String symbol, String side) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute(
        builder: (_) => LiveOrderScreen(symbol: symbol, closingSide: side),
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
  });
  final String symbol;
  final String? closingSide;
  final bool initialConditional;
  @override
  ConsumerState<LiveOrderScreen> createState() => _LiveOrderScreenState();
}

class _LiveOrderScreenState extends ConsumerState<LiveOrderScreen> {
  LiveOrderEntryMode mode = LiveOrderEntryMode.limit;
  LiveOrderEntryMode remembered = LiveOrderEntryMode.stopLimit;
  String get symbol => widget.symbol;
  String? get closingSide => widget.closingSide;
  bool get initialConditional => widget.initialConditional;

  void _selectMode(LiveOrderEntryMode next) {
    if (!mounted) return;
    final live = ref.read(liveOrderProvider), activity = ref.read(symbolSettingsActivityProvider);
    if (live.busy ||
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

  @override
  Widget build(BuildContext context) {
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
    final controller = ref.read(liveOrderProvider.notifier);
    final data = state.context?.symbol == symbol ? state.context : null;
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
        child: ListView(
          key: const Key('live-order-page'),
          padding: const EdgeInsets.all(16),
          children: [
            const OrderRecoveryNotice(),
            if (closingSide == null && !initialConditional)
              LiveOrderModeSelector(
                selected: mode,
                remembered: remembered,
                enabled:
                    !state.busy &&
                    !state.needsRecheck &&
                    settings.owner == null &&
                    !settings.recoveryBlocked &&
                    !auth.busy,
                onSelected: _selectMode,
              ),
            SelectableText(symbol, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(closingSide == null ? l10n.liveOrderScope : l10n.liveCloseScope),
            if (closingSide != null) SelectableText(closingSide!),
            const SizedBox(height: 12),
            if (identity?.walletAddress case final address?) SelectableText(address),
            FilledButton.icon(
              key: const Key('live-order-read'),
              onPressed: state.busy || state.needsRecheck || settings.owner != null || auth.busy
                  ? null
                  : identity?.signingAvailable == true && identity?.walletAddress != null
                  ? () => controller.load(symbol, includeFunds: closingSide == null)
                  : () => showAccountSheet(context),
              icon: const Icon(Icons.refresh),
              label: Text(
                identity == null
                    ? l10n.accountSignInToRead
                    : identity.walletAddress == null
                    ? l10n.createWallet
                    : !identity.signingAvailable
                    ? l10n.reconnectExternalWallet
                    : l10n.liveOrderReadContext,
              ),
            ),
            Text(
              closingSide == null ? l10n.liveOrderFundsReadHint : l10n.liveOrderReadHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (settings.owner != null && settings.owner != SymbolSetting.order)
              Text(l10n.liveOrderSettingsBusy, style: const TextStyle(color: AppColors.warning)),
            if (state.busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
            if (data != null) ...[
              const SizedBox(height: 16),
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
              if (state.stale)
                Text(
                  l10n.liveOrderContextExpired,
                  style: const TextStyle(color: AppColors.warning),
                ),
              LiveOrderForm(
                key: ValueKey((data.address, data.symbol, closingSide, initialConditional)),
                data: data,
                closingSide: closingSide,
                initialConditional: initialConditional,
                mode: closingSide == null && !initialConditional ? mode : null,
                onModeChanged: (next) {
                  setState(() {
                    mode = next;
                    if (next != LiveOrderEntryMode.limit && next != LiveOrderEntryMode.market) {
                      remembered = next;
                    }
                  });
                },
              ),
            ],
            const LiveOrderStatus(),
          ],
        ),
      ),
    );
  }
}

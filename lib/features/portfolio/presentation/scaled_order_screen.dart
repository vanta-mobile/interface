import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/scaled_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/position_margin_mode.dart';
import 'live_order_funds_panel.dart';
import 'order_recovery_notice.dart';
import 'scaled_order_form.dart';
import 'scaled_order_status.dart';

void openScaledOrder(BuildContext context, String symbol) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => ScaledOrderScreen(symbol: symbol)));

class ScaledOrderScreen extends ConsumerStatefulWidget {
  const ScaledOrderScreen({super.key, required this.symbol});
  final String symbol;
  @override
  ConsumerState<ScaledOrderScreen> createState() => _ScaledOrderScreenState();
}

class _ScaledOrderScreenState extends ConsumerState<ScaledOrderScreen> {
  late final ScaledOrderController controller;
  @override
  void initState() {
    super.initState();
    controller = ref.read(scaledOrderProvider.notifier);
  }

  @override
  void dispose() {
    // Defer provider notification until the route tree has finished unmounting.
    scheduleMicrotask(controller.stop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), live = ref.watch(liveOrderProvider);
    final state = ref.watch(scaledOrderProvider), auth = ref.watch(authProvider);
    final activity = ref.watch(symbolSettingsActivityProvider), identity = auth.identity;
    final data = live.context?.symbol == widget.symbol ? live.context : null;
    final locked =
        state.busy ||
        state.needsRecheck ||
        live.busy ||
        live.needsRecheck ||
        auth.busy ||
        activity.owner != null ||
        activity.recoveryBlocked;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.scaledTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            key: const Key('scaled-page'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OrderRecoveryNotice(),
                SelectableText(widget.symbol, style: Theme.of(context).textTheme.titleLarge),
                Text(l10n.liveOrderScope),
                ScaledReadControls(symbol: widget.symbol, locked: locked),
                if (data != null) ...[
                  ScaledContextDetails(data: data, stale: live.stale),
                  ScaledOrderForm(
                    key: ValueKey((
                      identity?.id,
                      data.address,
                      widget.symbol,
                      identity?.walletKind,
                      identity?.signingAvailable,
                    )),
                    data: data,
                    locked: locked,
                    ready: !live.stale,
                  ),
                ],
                ScaledOrderStatus(symbol: widget.symbol),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScaledReadControls extends ConsumerWidget {
  const ScaledReadControls({super.key, required this.symbol, required this.locked});
  final String symbol;
  final bool locked;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), live = ref.watch(liveOrderProvider);
    final identity = ref.watch(authProvider.select((s) => s.identity));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (identity?.walletAddress case final address?) SelectableText(address),
        FilledButton.icon(
          key: const Key('scaled-read'),
          onPressed: locked
              ? null
              : identity?.signingAvailable == true
              ? () => ref.read(liveOrderProvider.notifier).load(symbol)
              : () => showAccountSheet(context),
          icon: const Icon(Icons.refresh),
          label: Text(
            identity == null
                ? l10n.accountSignInToRead
                : identity.walletAddress == null
                ? l10n.createWallet
                : identity.signingAvailable
                ? l10n.liveOrderReadContext
                : l10n.reconnectExternalWallet,
          ),
        ),
        Text(l10n.liveOrderFundsReadHint),
        if (live.busy) const LinearProgressIndicator(),
        if (live.failure case final failure?)
          Text(tr(context, failure.key), style: const TextStyle(color: AppColors.negative)),
      ],
    );
  }
}

class ScaledContextDetails extends StatelessWidget {
  const ScaledContextDetails({super.key, required this.data, required this.stale});
  final LiveOrderContext data;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.liveOrderMarkPrice, '${data.markPrice} ${data.rules.quoteAsset}'),
        ValueRow(l10n.leverageCurrentSetting, '${data.leverage}×'),
        ValueRow(
          l10n.positionModeSettings,
          data.mode == FuturesPositionMode.oneWay
              ? l10n.positionModeOneWay
              : l10n.positionModeHedge,
        ),
        ValueRow(
          l10n.accountMarginMode,
          data.marginMode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode,
        ),
        LiveOrderFundsPanel(data: data, historical: stale),
        if (stale)
          Text(l10n.liveOrderContextExpired, style: const TextStyle(color: AppColors.warning)),
      ],
    );
  }
}

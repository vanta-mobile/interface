import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/futures_asset_mode_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../application/open_orders_provider.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/position_margin_mode.dart';
import 'mode_read_action.dart';
import 'mode_settings_sheet.dart';
import 'portfolio_components.dart';
import 'position_margin_mode_screen.dart';
import 'position_risk_screen.dart';
import 'aster_open_orders_panel.dart';

class MultiAssetActivationSheet extends ConsumerStatefulWidget {
  const MultiAssetActivationSheet({super.key});
  @override
  ConsumerState<MultiAssetActivationSheet> createState() => _MultiAssetActivationSheetState();
}

class _MultiAssetActivationSheetState extends ConsumerState<MultiAssetActivationSheet> {
  final affected = <String>{};
  bool managing = false;
  @override
  void initState() {
    super.initState();
    final context = ref.read(futuresAssetModeProvider).context;
    affected.addAll(context?.isolatedSymbols ?? []);
    affected.addAll(context?.markets.where((m) => m.requiresCross).map((m) => m.symbol) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(futuresAssetModeProvider), l = AppLocalizations.of(context);
    final controller = ref.read(futuresAssetModeProvider.notifier);
    ref.listen(
      authProvider.select(
        (s) => (s.identity?.id, s.identity?.walletAddress, s.identity?.walletKind),
      ),
      (_, next) {
        setState(affected.clear);
      },
    );
    final markets = {for (final m in state.context?.markets ?? <AssetModeMarket>[]) m.symbol: m};
    // New blockers discovered by a refresh must join the review as well.
    final symbols = {
      ...affected,
      ...?state.context?.isolatedSymbols,
      ...markets.values.where((m) => m.requiresCross).map((m) => m.symbol),
    }.toList()..sort();
    final known = symbols.every(markets.containsKey);
    final blocked = ref.watch(symbolSettingsActivityProvider).blocks(SymbolSetting.assetMode);
    final intent = known ? controller.prepare(FuturesAssetMode.multi) : null;
    final failure = state.failure ?? state.result?.failure;
    return ModeSheetBody(
      key: const Key('multi-asset-activation-sheet'),
      title: l.modeActivateMulti,
      onRefresh: state.needsRecheck ? controller.recheck : controller.load,
      children: [
        Text(
          l.modeMultiRequirements,
          style: TradeTypography.body.copyWith(color: TradeColors.muted),
        ),
        const SizedBox(height: 8),
        if (symbols.isNotEmpty) ...[
          Text(
            l.modeAffectedMarkets,
            style: TradeTypography.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final symbol in symbols)
            _AffectedMarket(
              key: ValueKey('affected-$symbol'),
              symbol: symbol,
              market: markets[symbol],
              enabled: !state.busy && !managing && !blocked && !state.needsRecheck,
              onManage: () => _manage(symbol, markets[symbol]),
            ),
        ],
        if (failure != null) ModeError(accountErrorText(context, failure)),
        if (state.needsRecheck) ModeError(l.assetModeOutcomeUnknown),
        if (state.result?.observed != null && state.result!.observed != state.intent?.target)
          ModeError(
            l.assetModeObservedDifferent(
              state.result!.observed == FuturesAssetMode.single
                  ? l.modeSingleShort
                  : l.modeMultiShort,
              l.modeMultiShort,
            ),
          ),
        if (state.stale || state.needsRecheck)
          ModeReadAction(
            key: const Key('multi-asset-refresh'),
            onRead: state.needsRecheck ? controller.recheck : controller.load,
            busy: state.busy,
            blocked: blocked || managing,
            recheck: state.needsRecheck,
          ),
        const SizedBox(height: 36),
        ModeAction(
          key: const Key('multi-asset-confirm'),
          label: l.modeConfirm,
          busy: state.busy || managing,
          onPressed: intent == null ? null : () => _confirm(intent),
        ),
      ],
    );
  }

  Future<void> _confirm(AssetModeIntent intent) async {
    final identity = ref.read(authProvider).identity;
    await ref.read(futuresAssetModeProvider.notifier).change(intent);
    if (mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        identity == ref.read(authProvider).identity &&
        ref.read(futuresAssetModeProvider).result?.observed == FuturesAssetMode.multi) {
      Navigator.pop(context);
    }
  }

  Future<void> _manage(String symbol, AssetModeMarket? market) async {
    final identity = ref.read(authProvider).identity;
    affected.add(symbol);
    setState(() => managing = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => market?.blocked != false
              ? market?.hasPosition == true || market?.hasCollateral == true
                    ? PositionRiskScreen(symbol: symbol)
                    : Scaffold(
                        appBar: AppBar(
                          title: Text(AppLocalizations.of(context).asterOpenOrdersTitle),
                        ),
                        body: SafeArea(
                          child: RefreshIndicator(
                            onRefresh: ref.read(openOrdersReadProvider.notifier).refresh,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: AsterOpenOrdersPanel(symbol: symbol),
                            ),
                          ),
                        ),
                      )
              : PositionMarginModeScreen(
                  symbol: symbol,
                  initialTarget: PositionMarginMode.cross,
                  readOnOpen: true,
                ),
        ),
      );
      if (!mounted || identity != ref.read(authProvider).identity) return;
      await ref.read(futuresAssetModeProvider.notifier).load();
    } finally {
      if (mounted) setState(() => managing = false);
    }
  }
}

class _AffectedMarket extends StatelessWidget {
  const _AffectedMarket({
    super.key,
    required this.symbol,
    required this.market,
    required this.enabled,
    required this.onManage,
  });
  final String symbol;
  final AssetModeMarket? market;
  final bool enabled;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ready = market?.marginMode == PositionMarginMode.cross;
    final blocked = market?.blocked != false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(symbol, style: PortfolioTypography.section),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ready ? TradeColors.accentBackground : TradeColors.card,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ready ? l.cross : l.accountIsolatedMode,
                    style: TradeTypography.caption.copyWith(
                      color: ready ? TradeColors.accent : TradeColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ready
                      ? l.modeRequirementsMet
                      : market?.hasPosition == true
                      ? l.modeOpenPosition
                      : (market?.openOrderCount ?? 0) > 0
                      ? l.modeOpenOrders
                      : market?.hasCollateral == true
                      ? l.modeIsolatedCollateral
                      : market == null
                      ? l.modeRefresh
                      : l.modeNoPositionsOrders,
                  style: TradeTypography.small.copyWith(
                    color: ready
                        ? TradeColors.accent
                        : blocked
                        ? TradeColors.negative
                        : TradeColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (ready)
            const SizedBox.square(
              dimension: 24,
              child: FittedBox(child: PortfolioIcon('notification-success.svg', size: 20)),
            )
          else
            Flexible(
              child: TextButton(
                onPressed: enabled ? onManage : null,
                style: TextButton.styleFrom(
                  foregroundColor: TradeColors.text,
                  backgroundColor: TradeColors.sheet,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  blocked ? l.modeManage : l.modeSwitchCross,
                  textAlign: TextAlign.center,
                  style: TradeTypography.caption.copyWith(
                    color: TradeColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

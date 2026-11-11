part of 'live_order_screen.dart';

/// Standalone order/close page chrome: explicit read controls, context
/// summary and scaffold. The trade workspace renders none of these.
extension _LiveOrderStandalone on _LiveOrderScreenState {
  List<Widget> _standaloneHeader({
    required LiveOrderState state,
    required AuthSession auth,
    required SymbolSettingsActivity settings,
    required MainOrderRefreshState refresh,
  }) {
    final l10n = AppLocalizations.of(context), identity = auth.identity;
    return [
      SelectableText(symbol, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(closingSide == null ? l10n.liveOrderScope : l10n.liveCloseScope),
      if (closingSide != null) SelectableText(closingSide!),
      const SizedBox(height: 12),
      if (identity?.walletAddress case final address?) SelectableText(address),
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
      if (refresh.failure case final failure? when !failure.requiresDeposit)
        Text(
          accountErrorText(context, failure),
          key: const Key('live-order-refresh-error'),
          style: const TextStyle(color: AppColors.negative),
        ),
      if (settings.owner != null && settings.owner != SymbolSetting.order)
        Text(l10n.liveOrderSettingsBusy, style: const TextStyle(color: AppColors.warning)),
      if (state.busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
    ];
  }

  List<Widget> _contextSummary(LiveOrderContext data, {required bool stale}) {
    final l10n = AppLocalizations.of(context);
    return [
      ValueRow(l10n.liveOrderMarkPrice, data.markPrice.toString()),
      ValueRow(l10n.leverageCurrentSetting, '${data.leverage}×'),
      ValueRow(
        l10n.accountMarginMode,
        data.marginMode == PositionMarginMode.cross ? l10n.cross : l10n.accountIsolatedMode,
      ),
      ValueRow(
        l10n.positionModeSettings,
        data.mode == FuturesPositionMode.oneWay ? l10n.positionModeOneWay : l10n.positionModeHedge,
      ),
      if (stale)
        Text(l10n.liveOrderContextExpired, style: const TextStyle(color: AppColors.warning)),
    ];
  }

  Widget _standalonePage(List<Widget> children) {
    final l10n = AppLocalizations.of(context);
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

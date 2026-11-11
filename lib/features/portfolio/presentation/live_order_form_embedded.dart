part of 'live_order_form.dart';

/// Trade-workspace layout from the Futures design. It reuses the form state,
/// sizing and review paths; optional order settings move into Advanced.
extension _LiveOrderEmbeddedLayout on _LiveOrderFormState {
  Widget _embeddedLayout({
    required LiveOrderContext contextData,
    required String? invalid,
    required bool enabled,
  }) {
    final l10n = AppLocalizations.of(context);
    final entry = draft, postOnly = timeInForce == LiveOrderTimeInForce.postOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (contextData.fundsFailure case final failure?)
          _errorText(accountErrorText(context, failure)),
        if (contextData.funds?.account.canTrade == false) _errorText(l10n.liveOrderTradingDisabled),
        if (trailing) _trailingControls(contextData, enabled, showToggle: false),
        if (conditional && !trailing) ...[
          EmbeddedTriggerField(
            controller: triggerPrice,
            basis: triggerBasis,
            enabled: enabled,
            onPrice: () => _render(() {}),
            onBasis: (value) => _render(() => triggerBasis = value),
          ),
          const SizedBox(height: 8),
        ],
        // Stop/take-profit market orders have only a trigger price, as designed.
        if (!(market && (conditional || trailing)))
          EmbeddedPriceField(
            controller: price,
            asset: contextData.rules.quoteAsset,
            tick: contextData.rules.priceTick,
            enabled: enabled,
            fixedLabel: market
                ? l10n.market
                : entry.pegged
                ? l10n.liveOrderBbo
                : null,
            bboSelected: entry.pegged,
            onBbo: market || trailing ? null : () => _toggleBbo(postOnly),
            onChanged: () => _render(() => _limitEdited = true),
          ),
        if (!(market && (conditional || trailing))) const SizedBox(height: 8),
        EmbeddedSizeField(
          data: contextData,
          unit: sizeUnit,
          controller: _allocationPercent != null
              ? _ratioInput
              : sizeUnit == OrderSizeUnit.base
              ? quantity
              : quoteAmount,
          enabled: enabled,
          onUnit: _onSizeUnit,
          onInput: _onSizeInput,
        ),
        const SizedBox(height: 8),
        MainOrderPercentageControl(
          unit: sizeUnit,
          manualCheck: entry.attachment?.entryPeg == null,
          compact: true,
        ),
        _availableRow(contextData),
        EmbeddedAdvancedSection(children: _advancedControls(contextData, entry, enabled)),
        if (invalid != null && sizeInput.text.isNotEmpty) _errorText(tr(context, invalid)),
        MainOrderCapacityPanel(
          data: widget.data,
          draft: entry,
          unit: sizeUnit,
          input: sizeInput.text,
          percent: _allocationPercent,
          compact: true,
          reviewWithoutPreview: entry.attachment?.entryPeg != null,
          onRefresh: _refreshForReview,
          onReview: enabled && (_allocationPercent == null || _allocationPercent! > 0)
              ? _reviewDirection
              : null,
        ),
      ],
    );
  }

  /// Design rows: TP/SL, Hidden Order, then Reduce only with the remaining
  /// time-in-force choices. Market orders have no time-in-force.
  List<Widget> _advancedControls(LiveOrderContext data, LiveOrderDraft entry, bool enabled) {
    final l10n = AppLocalizations.of(context);
    final fixed = widget.mode == LiveOrderEntryMode.postOnly;
    final hidden = timeInForce == LiveOrderTimeInForce.hidden;
    final policies = [
      for (final policy in LiveOrderTimeInForce.values)
        if (policy != LiveOrderTimeInForce.hidden && data.rules.timeInForce.contains(policy))
          policy,
    ];
    void policy(LiveOrderTimeInForce value) {
      _render(() {
        timeInForce = value;
        if (value == LiveOrderTimeInForce.postOnly) _constrainPostOnly();
      });
      widget.onModeChanged?.call(liveOrderEntryMode(draft));
    }

    final oneWay = data.mode == FuturesPositionMode.oneWay;
    final showPolicy = !market && !hidden && policies.isNotEmpty;
    return [
      LiveOrderAttachmentControls(
        key: ValueKey((data.address, attachmentGeneration, 'attachment')),
        allowed: !reducing && !trailing,
        enabled: enabled,
        data: data,
        entry: attachmentEntry,
        compact: true,
        onChanged: (value) => _render(() => attachment = value),
      ),
      if (!market &&
          !fixed &&
          !trailing &&
          data.rules.timeInForce.contains(LiveOrderTimeInForce.hidden))
        EmbeddedCheckRow(
          key: const Key('live-order-hidden'),
          label: l10n.tradeHiddenOrder,
          value: hidden,
          onChanged: enabled
              ? (value) => policy(value ? LiveOrderTimeInForce.hidden : LiveOrderTimeInForce.gtc)
              : null,
        ),
      if (oneWay || showPolicy)
        EmbeddedCheckRow(
          key: const Key('live-order-reduce-only'),
          label: l10n.reduceOnly,
          value: entry.reduceOnly,
          onChanged: oneWay && enabled ? (value) => _render(() => reduceOnly = value) : null,
          trailing: showPolicy
              ? PopupMenuButton<LiveOrderTimeInForce>(
                  key: const Key('live-order-policy'),
                  enabled: enabled && !fixed,
                  tooltip: l10n.liveOrderPolicy,
                  initialValue: timeInForce,
                  onSelected: policy,
                  itemBuilder: (_) => [
                    for (final value in policies)
                      PopupMenuItem(value: value, child: Text(liveOrderPolicyLabel(l10n, value))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(timeInForce.wire, style: TradeTypography.caption),
                        const Icon(Icons.arrow_drop_down, size: 14, color: TradeColors.muted),
                      ],
                    ),
                  ),
                )
              : null,
        ),
    ];
  }

  void _toggleBbo(bool postOnly) => _render(() {
    if (attaching) {
      entryPeg = entryPeg != null
          ? null
          : postOnly
          ? AttachedEntryPeg.queue1
          : AttachedEntryPeg.counterparty1;
    } else {
      peg = peg != null
          ? null
          : postOnly
          ? LiveOrderPeg.queue
          : LiveOrderPeg.counterparty;
    }
  });

  Widget _availableRow(LiveOrderContext data) {
    final l10n = AppLocalizations.of(context);
    final available = data.funds?.account.availableBalance;
    return Row(
      key: const Key('live-order-available'),
      children: [
        Expanded(
          child: Text(
            l10n.available,
            style: TradeTypography.body.copyWith(color: TradeColors.secondary),
          ),
        ),
        Text(
          available == null
              ? '—'
              : '${TokenAmountFormatter.formatCompact(DecimalValue(available.toString()))} '
                    '${data.rules.quoteAsset}',
          style: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          key: const Key('live-order-deposit'),
          tooltip: l10n.fundingDeposit,
          onPressed: () => openFunding(context, FundingOperation.deposit),
          icon: const Icon(Icons.add_circle_outline, size: 14),
          color: TradeColors.accent,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 28, height: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TradeTypography.small.copyWith(color: TradeColors.negative)),
  );

  /// Order data expires after 30 seconds. Pressing a direction is the explicit
  /// refresh; review continues only once the form has rebuilt on new data.
  Future<bool> _refreshForReview(bool direction) async {
    _render(() => buy = direction);
    final ok = await ref.read(mainOrderRefreshProvider.notifier).refresh(widget.data.symbol);
    if (!ok || !mounted) return false;
    await WidgetsBinding.instance.endOfFrame;
    return mounted;
  }

  /// Compound-entry pegs keep their direct review; others use the allocation
  /// review, which re-checks capacity before any signing.
  Future<void> _reviewDirection(bool direction) async {
    if (!reducing && draft.attachment?.entryPeg == null) {
      return _reviewAllocated(direction: direction);
    }
    _render(() => buy = direction);
    final contextData = _pricingContext ?? widget.data, size = sizing;
    if (size.failure != null || attachmentFailure != null || contextData.validate(draft) != null) {
      return;
    }
    final intent = ref
        .read(liveOrderProvider.notifier)
        .prepare(contextData.symbol, draft, pricingContext: _pricingContext);
    if (intent != null) await reviewLiveOrder(context, ref, intent, sizing: size);
  }
}

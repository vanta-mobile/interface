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
    final bboLevel = _bboLevel == null ? null : _bboLevelLabel(l10n, _bboLevel!);
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
            fixedLabel: market ? l10n.market : null,
            bboSelected: entry.pegged,
            onBbo: market || trailing ? null : () => _toggleBbo(postOnly),
            bboLevel: market || !entry.pegged ? null : bboLevel,
            onBboLevel: () => _chooseBboLevel(postOnly),
            onChanged: () => _render(() => _limitEdited = true),
          ),
        if (!(market && (conditional || trailing))) const SizedBox(height: 8),
        EmbeddedSizeField(
          minimumHint: minimumOrderSizeHint(
            context,
            data: _pricingContext,
            draft: entry,
            unit: sizeUnit,
            bothDirections: !reducing,
          ),
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
        if (!ref.watch(mainOrderRefreshProvider).loading &&
            !_pricingPending &&
            invalid != null &&
            sizeInput.text.isNotEmpty)
          _errorText(_validationText(invalid)),
        MainOrderCapacityPanel(
          data: widget.data,
          draft: entry,
          unit: sizeUnit,
          input: sizeInput.text,
          percent: _allocationPercent,
          compact: true,
          reviewWithoutPreview: entry.attachment?.entryPeg != null,
          onRefresh: _refreshForReview,
          refreshingReviewDirection: _refreshingReviewDirection,
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
    final policies = {
      for (final policy in [LiveOrderTimeInForce.gtc, LiveOrderTimeInForce.ioc])
        if (data.rules.timeInForce.contains(policy)) policy,
    };
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
              ? EmbeddedTimeInForceSelector(
                  key: const Key('live-order-policy'),
                  selected: timeInForce,
                  available: policies,
                  onChanged: enabled && !fixed ? policy : null,
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

  /// Ordinary pegs map onto their level-1 equivalents so one sheet serves
  /// both endpoints.
  AttachedEntryPeg? get _bboLevel => attaching
      ? entryPeg
      : switch (peg) {
          LiveOrderPeg.counterparty => AttachedEntryPeg.counterparty1,
          LiveOrderPeg.queue => AttachedEntryPeg.queue1,
          null => null,
        };

  String _bboLevelLabel(AppLocalizations l10n, AttachedEntryPeg level) => level.counterparty
      ? l10n.liveOrderBboCounterparty(level.depth)
      : l10n.liveOrderBboQueue(level.depth);

  /// Offers every documented level: compound entries support ten depths,
  /// ordinary orders only level one, and Post Only BBO only same-side level one.
  Future<void> _chooseBboLevel(bool postOnly) async {
    final current = _bboLevel, attached = attaching;
    if (current == null) return;
    final l10n = AppLocalizations.of(context);
    final levels = [
      for (final level
          in attached
              ? AttachedEntryPeg.values
              : const [AttachedEntryPeg.counterparty1, AttachedEntryPeg.queue1])
        if (!postOnly || level == AttachedEntryPeg.queue1) level,
    ];
    final value = await showTradeOptionSheet(
      context,
      key: const Key('live-order-bbo-levels'),
      title: l10n.liveOrderBboModeTitle,
      selected: current,
      footer: l10n.liveOrderBboModeHint,
      options: [
        for (final level in levels)
          (value: level, label: _bboLevelLabel(l10n, level), description: null),
      ],
    );
    // The form may have switched between ordinary and compound pricing.
    if (value == null || !mounted || attaching != attached || _bboLevel == null) return;
    _render(() {
      if (attached) {
        entryPeg = value;
      } else {
        peg = value.counterparty ? LiveOrderPeg.counterparty : LiveOrderPeg.queue;
      }
    });
  }

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

  /// An explicit click may need fresh facts before review. Only this
  /// direction's button shows progress; background renewal stays silent.
  Future<bool> _refreshForReview(bool direction) async {
    if (_refreshingReviewDirection != null) return false;
    _render(() {
      buy = direction;
      _refreshingReviewDirection = direction;
    });
    try {
      final refresh = ref.read(mainOrderRefreshProvider.notifier);
      if (ref.read(mainOrderRefreshProvider).background) refresh.stop();
      final ok = await refresh.refresh(widget.data.symbol);
      if (!ok || !mounted) return false;
      await WidgetsBinding.instance.endOfFrame;
      return mounted;
    } finally {
      if (mounted) _render(() => _refreshingReviewDirection = null);
    }
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

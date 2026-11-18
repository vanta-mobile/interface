part of 'live_order_form.dart';

/// Trade-workspace layout from the Futures design. It reuses the form state,
/// sizing and review paths; optional order settings move into Advanced.
extension _LiveOrderEmbeddedLayout on _LiveOrderFormState {
  Widget _embeddedLayout({required LiveOrderContext contextData, required bool enabled}) {
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
        if (trailing) _trailingControls(enabled),
        if (conditional && !trailing) ...[
          EmbeddedTriggerField(
            controller: triggerPrice,
            basis: triggerBasis,
            enabled: enabled,
            error: _triggerReachedTerms == _formTerms ? l10n.liveOrderTriggerReached : null,
            onPrice: () => _render(() {}),
            onBasis: (value) => _render(() => triggerBasis = value),
          ),
          const SizedBox(height: 8),
        ],
        // Market orders have no price box, as designed; stop/take-profit
        // market orders keep only their trigger price.
        if (!market)
          EmbeddedPriceField(
            controller: price,
            asset: contextData.rules.quoteAsset,
            tick: contextData.rules.priceTick,
            enabled: enabled,
            fixedLabel: market ? l10n.market : null,
            bboSelected: entry.pegged,
            // As on Aster's site, BBO is unavailable while TP/SL is checked.
            onBbo: market || trailing || attaching ? null : () => _toggleBbo(postOnly),
            bboVisible: true,
            bboLevel: market || !entry.pegged ? null : bboLevel,
            onBboLevel: () => _chooseBboLevel(postOnly),
            onChanged: () => _render(() => _limitEdited = true),
          ),
        if (!market) const SizedBox(height: 8),
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
        // The 24px slider box centres its 12px design track 8px below the field.
        const SizedBox(height: 2),
        MainOrderPercentageControl(
          unit: sizeUnit,
          manualCheck: entry.attachment?.entryPeg == null,
          compact: true,
          scale: _sliderScale(entry),
          amount: _allocationPercent == null ? parseOrderDecimal(_manualSizeInput.text) : null,
          onAmount: _onSliderAmount,
        ),
        EmbeddedAvailableRow(data: contextData),
        EmbeddedAdvancedSection(children: _advancedControls(contextData, entry, enabled)),
        MainOrderCapacityPanel(
          data: widget.data,
          draft: entry,
          unit: sizeUnit,
          input: sizeInput.text,
          percent: _allocationPercent,
          compact: true,
          reviewFailure: _reviewFailure?.terms == _formTerms ? _reviewFailure!.failure : null,
          reviewWithoutPreview: entry.attachment?.entryPeg != null,
          onRefresh: _refreshForReview,
          // A confirmation dialog covering the form owns the progress display.
          refreshingReviewDirection:
              _refreshingReviewDirection ??
              (ModalRoute.of(context)?.isCurrent == false ? null : _reviewingDirection),
          onReview:
              enabled &&
                  _reviewingDirection == null &&
                  (_allocationPercent == null || _allocationPercent! > 0)
              ? _reviewDirection
              : null,
        ),
      ],
    );
  }

  /// Design rows: TP/SL, Hidden Order, then Reduce only with the remaining
  /// time-in-force choices. Market orders have no time-in-force, Post Only
  /// fixes it, conditional orders have no Hidden Order, and hedge mode has no
  /// Reduce only. Exclusive options follow the latest choice, as on Aster's
  /// site: checking TP/SL clears BBO, Hidden Order and Reduce only; checking
  /// Hidden Order or Reduce only clears TP/SL; GTC/IOC clears Hidden Order.
  /// Hidden Order and Reduce only may be combined.
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
        if (policies.contains(value)) _policy = value;
        if (value == LiveOrderTimeInForce.postOnly) _constrainPostOnly();
        if (value == LiveOrderTimeInForce.hidden) _clearAttachment();
      });
      widget.onModeChanged?.call(liveOrderEntryMode(draft));
    }

    final oneWay = data.mode == FuturesPositionMode.oneWay;
    final showPolicy = !market && !fixed && policies.isNotEmpty;
    final selector = showPolicy
        ? EmbeddedTimeInForceSelector(
            key: const Key('live-order-policy'),
            selected: hidden ? _policy : timeInForce,
            inactive: hidden,
            available: policies,
            onChanged: enabled ? policy : null,
          )
        : null;
    return [
      LiveOrderAttachmentControls(
        key: ValueKey((data.address, attachmentGeneration, 'attachment')),
        // Closing a hedge position takes no entry TP/SL.
        allowed: !trailing && !_hedgeClosing,
        enabled: enabled,
        data: data,
        entry: attachmentEntry,
        compact: true,
        onChanged: (value) => _render(() {
          final checked = attachment == null && value != null;
          attachment = value;
          if (checked) {
            reduceOnly = false;
            peg = null;
            if (timeInForce == LiveOrderTimeInForce.hidden) timeInForce = _policy;
          }
        }),
      ),
      if (!market &&
          !fixed &&
          !trailing &&
          !conditional &&
          data.rules.timeInForce.contains(LiveOrderTimeInForce.hidden))
        EmbeddedCheckRow(
          key: const Key('live-order-hidden'),
          label: l10n.tradeHiddenOrder,
          help: l10n.tradeHiddenOrderHelp,
          value: hidden,
          onChanged: enabled
              ? (value) => policy(value ? LiveOrderTimeInForce.hidden : _policy)
              : null,
        ),
      if (oneWay)
        EmbeddedCheckRow(
          key: const Key('live-order-reduce-only'),
          label: l10n.reduceOnly,
          help: l10n.tradeReduceOnlyHelp,
          value: entry.reduceOnly,
          onChanged: enabled ? _setReduceOnly : null,
          trailing: selector,
        )
      else if (selector != null)
        Align(alignment: AlignmentDirectional.centerEnd, child: selector),
    ];
  }

  void _setReduceOnly(bool value) => _render(() {
    reduceOnly = value;
    if (value) _clearAttachment();
  });

  /// Remounting the TP/SL controls clears their checkbox and inputs.
  void _clearAttachment() {
    if (attachment == null) return;
    attachment = null;
    attachmentGeneration++;
  }

  void _toggleBbo(bool postOnly) => _render(() {
    peg = peg != null
        ? null
        : postOnly
        ? LiveOrderPeg.queue
        : LiveOrderPeg.counterparty;
  });

  /// The sheet lists ordinary pegs by their level-1 names.
  AttachedEntryPeg? get _bboLevel => switch (peg) {
    LiveOrderPeg.counterparty => AttachedEntryPeg.counterparty1,
    LiveOrderPeg.queue => AttachedEntryPeg.queue1,
    null => null,
  };

  String _bboLevelLabel(AppLocalizations l10n, AttachedEntryPeg level) => level.counterparty
      ? l10n.liveOrderBboCounterparty(level.depth)
      : l10n.liveOrderBboQueue(level.depth);

  /// Ordinary orders (`POST /fapi/v3/order`) document only level one, and
  /// Post Only BBO only same-side level one.
  Future<void> _chooseBboLevel(bool postOnly) async {
    final current = _bboLevel;
    if (current == null) return;
    final l10n = AppLocalizations.of(context);
    final levels = [
      for (final level in const [AttachedEntryPeg.counterparty1, AttachedEntryPeg.queue1])
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
    if (value == null || !mounted || _bboLevel == null) return;
    _render(() => peg = value.counterparty ? LiveOrderPeg.counterparty : LiveOrderPeg.queue);
  }

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TradeTypography.small.copyWith(color: TradeColors.negative)),
  );

  /// An explicit click may need fresh facts before review. Only this
  /// direction's button shows progress; background renewal stays silent.
  Future<bool> _refreshForReview(bool direction) async {
    if (_refreshingReviewDirection != null) return false;
    // A focused size field would reopen the keyboard when it is re-enabled.
    FocusScope.of(context).unfocus();
    _render(() {
      buy = direction;
      _refreshingReviewDirection = direction;
      _reviewFailure = null;
    });
    try {
      final refresh = ref.read(mainOrderRefreshProvider.notifier);
      if (ref.read(mainOrderRefreshProvider).background) refresh.stop();
      var ok = await refresh.refresh(widget.data.symbol);
      // Facts that moved between the account and capacity reads are read once more.
      if (!ok &&
          mounted &&
          _changedFacts.contains(ref.read(mainOrderRefreshProvider).failure?.key)) {
        ok = await refresh.refresh(widget.data.symbol);
      }
      if (!mounted) return false;
      if (!ok) {
        // A clicked read reports its cause until dismissed; background
        // renewals may replace the provider's failure at any time.
        final failure = ref.read(mainOrderRefreshProvider).failure;
        AppToast.showFailure(
          context,
          accountErrorText(context, failure ?? const AccountReadFailure('liveAllocationChanged')),
        );
        return false;
      }
      await WidgetsBinding.instance.endOfFrame;
      return mounted;
    } finally {
      if (mounted) _render(() => _refreshingReviewDirection = null);
    }
  }

  /// Compound-entry pegs keep their direct review; others use the allocation
  /// review, which re-checks capacity before any signing.
  Future<void> _reviewDirection(bool direction) async {
    if (_reviewingDirection != null) return;
    FocusScope.of(context).unfocus();
    _render(() {
      buy = direction;
      _reviewingDirection = direction;
      _reviewFailure = null;
    });
    try {
      await _reviewSelected(direction);
    } finally {
      if (mounted) _render(() => _reviewingDirection = null);
    }
  }

  Future<void> _reviewSelected(bool direction) async {
    if (!reducing && draft.attachment?.entryPeg == null) {
      return _reviewAllocated(direction: direction);
    }
    final contextData = _pricingContext ?? widget.data, size = sizing;
    final invalid = size.failure ?? attachmentFailure ?? contextData.validate(draft);
    if (invalid == _triggerReachedKey) {
      _render(() => _triggerReachedTerms = _formTerms);
      return;
    }
    if (invalid != null) {
      final failure = _pricing.failure?.key == invalid ? _pricing.failure! : null;
      _render(
        () => _reviewFailure = (failure: failure ?? AccountReadFailure(invalid), terms: _formTerms),
      );
      return;
    }
    // Public prices can lag the account read a click just renewed; their
    // anchor must match the current account facts to price this order.
    final live = ref.read(liveOrderProvider).context, pricing = _pricingContext;
    final intent = ref
        .read(liveOrderProvider.notifier)
        .prepare(
          contextData.symbol,
          draft,
          pricingContext: pricing != null && live != null && live.sameAccountAnchor(pricing)
              ? pricing
              : null,
        );
    if (intent == null) {
      // The click is answered with its concrete cause, never silently ignored.
      final current = ref.read(liveOrderProvider);
      _render(
        () => _reviewFailure = (
          failure:
              current.failure ??
              AccountReadFailure(current.context?.validate(draft) ?? 'liveAllocationChanged'),
          terms: _formTerms,
        ),
      );
      return;
    }
    final placed = await reviewLiveOrder(
      context,
      ref,
      intent,
      sizing: size,
      alwaysConfirm: _prefilled,
    );
    if (placed) _clearSize();
  }
}

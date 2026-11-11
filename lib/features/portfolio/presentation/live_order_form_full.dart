part of 'live_order_form.dart';

/// Standalone order, close and position-trigger layout. The trade workspace
/// uses [_LiveOrderEmbeddedLayout] over the same state and review paths.
extension _LiveOrderFullLayout on _LiveOrderFormState {
  Widget _fullLayout({
    required LiveOrderContext contextData,
    required String? invalid,
    required LiveOrderIntent? intent,
    required OrderSizeResolution size,
    required bool enabled,
    required bool stale,
    required bool pending,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        if (widget.closingSide == null) LiveOrderFundsPanel(data: contextData, historical: stale),
        if (widget.closingSide == null)
          SegmentedButton<bool>(
            key: const Key('live-order-direction'),
            segments: [
              ButtonSegment(value: true, label: Text(l10n.long)),
              ButtonSegment(value: false, label: Text(l10n.short)),
            ],
            selected: {buy},
            onSelectionChanged: !enabled ? null : (value) => _render(() => buy = value.first),
          ),
        LiveOrderReductionControls(
          data: contextData,
          draft: draft,
          enabled: enabled,
          onReduce: (value) => _render(() => reduceOnly = value),
          onFraction: (percent) => _render(() {
            sizeUnit = OrderSizeUnit.base;
            quantity.text = contextData
                .closeFraction(
                  widget.closingSide!,
                  percent,
                  market: market,
                  conditional: conditional || trailing,
                )
                .toString();
          }),
        ),
        if (!widget.initialConditional && (widget.mode == null || trailing))
          _trailingControls(contextData, enabled, showToggle: widget.mode == null),
        if (!trailing && (widget.mode == null || conditional))
          _triggerControls(contextData, draft, enabled, showToggle: widget.mode == null),
        const SizedBox(height: 12),
        if (widget.mode == null)
          SegmentedButton<bool>(
            key: const Key('live-order-type'),
            segments: [
              ButtonSegment(value: false, label: Text(l10n.limit)),
              ButtonSegment(value: true, label: Text(l10n.market)),
            ],
            selected: {market},
            onSelectionChanged: !enabled || entireClose || trailing
                ? null
                : (value) => _render(() => market = value.first),
          ),
        if (widget.initialConditional && widget.closingSide != null)
          LiveOrderEntireControls(
            selected: entireClose,
            market: market,
            enabled: enabled,
            onChanged: (value) => _render(() => entireClose = value),
          ),
        const SizedBox(height: 12),
        if (!reducing)
          MainOrderPercentageControl(
            unit: sizeUnit,
            manualCheck: draft.attachment?.entryPeg == null,
          ),
        if (!entireClose)
          LiveOrderSizeField(
            data: contextData,
            draft: draft,
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
        LiveOrderPriceInputs(
          data: contextData,
          draft: draft,
          price: price,
          policy: timeInForce,
          fixedPolicy: widget.mode == LiveOrderEntryMode.postOnly,
          peg: peg,
          entryPeg: entryPeg,
          enabled: enabled,
          onPolicy: (value) {
            _render(() {
              timeInForce = value;
              if (value == LiveOrderTimeInForce.postOnly) _constrainPostOnly();
            });
            widget.onModeChanged?.call(liveOrderEntryMode(draft));
          },
          onPeg: (value) => _render(() => peg = value),
          onEntryPeg: (value) => _render(() => entryPeg = value),
          onPrice: () => _render(() => _limitEdited = true),
        ),
        LiveOrderAttachmentControls(
          key: ValueKey((contextData.address, attachmentGeneration, 'attachment')),
          allowed: !reducing && !trailing,
          enabled: enabled,
          data: contextData,
          entry: attachmentEntry,
          onChanged: (value) => _render(() => attachment = value),
        ),
        const SizedBox(height: 8),
        if (invalid != null &&
            (sizeInput.text.isNotEmpty ||
                triggerPrice.text.isNotEmpty ||
                trailingRate.text.isNotEmpty ||
                trailingActivation.text.isNotEmpty))
          Text(tr(context, invalid), style: const TextStyle(color: AppColors.negative)),
        if (widget.closingSide != null && contextData.reductionPosition(draft)?.quantity == null)
          Text(l10n.liveClosePositionChanged, style: const TextStyle(color: AppColors.warning)),
        LiveOrderSizePreview(value: size, data: contextData),
        if (!size.converted)
          if (parseOrderDecimal(draft.quantity) case final amount?)
            if (contextData.referenceExecutionPrice(draft) case final executionPrice?)
              ValueRow(
                l10n.liveOrderEstimatedNotional,
                '${amount * executionPrice} ${contextData.rules.quoteAsset}',
              ),
        const SizedBox(height: 12),
        if (widget.closingSide == null) LiveOrderCostPreview(data: contextData, draft: draft),
        if (!reducing)
          MainOrderCapacityPanel(
            data: widget.data,
            draft: draft,
            unit: sizeUnit,
            input: sizeInput.text,
            percent: _allocationPercent,
            showReview: true,
            onReview: enabled && (_allocationPercent == null || _allocationPercent! > 0)
                ? (direction) => _reviewAllocated(direction: direction)
                : null,
          ),
        LiveOrderSubmitControls(
          draft: draft,
          enabled: enabled,
          pending: pending,
          onSubmit: intent == null
              ? null
              : !reducing && draft.attachment?.entryPeg == null
              ? _reviewAllocated
              : () => reviewLiveOrder(context, ref, intent, sizing: size),
        ),
      ],
    );
  }

  Widget _triggerControls(
    LiveOrderContext data,
    LiveOrderDraft entry,
    bool enabled, {
    required bool showToggle,
  }) => LiveOrderTriggerControls(
    showToggle: showToggle,
    fixedConditional: widget.initialConditional,
    data: data,
    draft: entry,
    price: triggerPrice,
    enabled: enabled,
    onEnabled: (value) => _render(() => conditional = value),
    onKind: (value) => _render(() => triggerKind = value),
    onBasis: (value) => _render(() => triggerBasis = value),
    onProtect: (value) => _render(() => protect = value),
    onPrice: () => _render(() {}),
  );
}

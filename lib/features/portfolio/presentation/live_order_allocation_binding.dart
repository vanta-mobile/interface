part of 'live_order_form.dart';

/// Text-controller adaptation only. Exact sizing, refreshed limits and signing
/// guards belong to domain/application code, never to the widget callbacks.
extension _LiveOrderAllocationBinding on _LiveOrderFormState {
  int? get _allocationPercent => reducing ? null : ref.read(mainOrderAllocationProvider).percent;
  LiveOrderSize get _manualSizeInput => LiveOrderSize(
    unit: sizeUnit,
    text: sizeUnit == OrderSizeUnit.base ? quantity.text : quoteAmount.text,
  );

  MainOrderSidePreview? _allocationSide(LiveOrderDraft entry) {
    final preview = ref.read(
      mainOrderCapacityPreviewProvider((
        context: widget.data,
        draft: entry,
        unit: sizeUnit,
        input: _manualSizeInput.text,
        percent: _allocationPercent,
      )),
    );
    if (preview == null) return null;
    return entry.buy ? preview.buy : preview.sell;
  }

  LiveOrderContext? get _pricingContext {
    if (reducing) return widget.data;
    try {
      return ref.read(mainOrderPricingProvider).priceContext(widget.data);
    } on AccountReadFailure {
      return null;
    }
  }

  OrderSizeResolution _resolveSize(LiveOrderDraft entry) {
    if (_allocationPercent == null) {
      final context = _pricingContext;
      if (context == null) {
        return const OrderSizeResolution(failure: 'liveCapacityPriceUnavailable');
      }
      return _manualSizeInput.resolve(context, entry);
    }
    if (_allocationPercent == 0) return const OrderSizeResolution(quantity: '');
    final side = _allocationSide(entry);
    return side?.size ?? OrderSizeResolution(failure: side?.failure?.key ?? 'liveCapacityStale');
  }

  void _syncRatioInput() {
    if (_allocationPercent == null ||
        ref.read(mainOrderRefreshProvider).loading ||
        ref.read(mainOrderAllocationProvider).preparing ||
        ref.read(liveOrderProvider).busy) {
      return;
    }
    final side = _allocationSide(
      rawDraft(attaching ? LiveOrderAttachment(entryPeg: market ? null : entryPeg) : null),
    );
    // Keep the previous display during an unsuccessful refresh. It cannot be
    // submitted without a fresh resolution; never relabel an old unit value.
    final text = _allocationPercent == 0
        ? ''
        : side?.size != null
        ? side!.displayInput(sizeUnit)
        : null;
    if (text != null && text != _ratioInput.text) _ratioInput.text = text;
  }

  void _onSizeInput() {
    if (_allocationPercent != null) {
      (sizeUnit == OrderSizeUnit.base ? quantity : quoteAmount).text = _ratioInput.text;
    }
    if (!reducing) ref.read(mainOrderAllocationProvider.notifier).manual();
    _render(() {});
  }

  void _onSizeUnit(OrderSizeUnit value) {
    _render(() {
      if (_allocationPercent != null && value != sizeUnit) _ratioInput.clear();
      sizeUnit = value;
    });
  }

  Object get _formTerms => (
    liveOrderDraftKey(rawDraft(null)),
    sizeUnit,
    quantity.text,
    quoteAmount.text,
    attachment,
    entryPeg,
    widget.data,
    _allocationPercent,
  );

  Future<void> _reviewAllocated({bool? direction}) async {
    if (direction != null && direction != buy) _render(() => buy = direction);
    final candidate = draft, terms = _formTerms, capturedSize = sizing;
    final controller = ref.read(mainOrderAllocationProvider.notifier);
    final review = await controller.prepare(
      candidate,
      isFormCurrent: () => mounted && _formTerms == terms,
    );
    if (!mounted || review == null) return;
    await reviewLiveOrder(
      context,
      ref,
      LiveOrderIntent(
        context: review.valuation?.context ?? review.intent.context,
        draft: review.intent.draft,
        clientOrderId: review.intent.clientOrderId,
        revision: review.intent.revision,
      ),
      sizing: capturedSize,
      onSubmit: () => controller.submit(review),
      extraTerms: MainOrderAllocationTerms(review: review),
    );
  }
}

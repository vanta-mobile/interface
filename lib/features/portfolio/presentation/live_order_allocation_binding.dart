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

  ({LiveOrderContext? context, AccountReadFailure? failure}) get _pricing {
    if (reducing) return (context: widget.data, failure: null);
    try {
      return (context: ref.read(mainOrderPricingProvider).priceContext(widget.data), failure: null);
    } on AccountReadFailure catch (failure) {
      return (context: null, failure: failure);
    }
  }

  LiveOrderContext? get _pricingContext => _pricing.context;
  bool get _pricingPending => switch (ref.read(mainOrderPricingProvider)) {
    MainOrderMarketData(pending: true) => true,
    _ => false,
  };

  String _validationText(String key) {
    final failure = _pricing.failure;
    return accountErrorText(context, failure?.key == key ? failure! : AccountReadFailure(key));
  }

  OrderSizeResolution _resolveSize(LiveOrderDraft entry) {
    if (_allocationPercent == null) {
      final context = _pricingContext;
      if (context == null) {
        return OrderSizeResolution(
          failure: _pricing.failure?.key ?? 'liveCapacityPriceUnavailable',
        );
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

  /// The slider's range: the smaller directional maximum in the shown unit,
  /// from the same preview the direction cards use.
  MainOrderSliderScale? _sliderScale(LiveOrderDraft entry) {
    final preview = ref.watch(
      mainOrderCapacityPreviewProvider((
        context: widget.data,
        draft: entry,
        unit: sizeUnit,
        input: sizeInput.text,
        percent: _allocationPercent,
      )),
    );
    final buy = preview?.buy.capacity, sell = preview?.sell.capacity;
    if (buy == null || sell == null) return null;
    Decimal shown(LiveOrderSideCapacity side) =>
        sizeUnit == OrderSizeUnit.base ? side.maximum : side.maximumQuote;
    final maximum = shown(buy) < shown(sell) ? shown(buy) : shown(sell);
    if (maximum <= Decimal.zero) return null;
    return (
      maximum: maximum,
      fine: sizeUnit == OrderSizeUnit.base ? buy.rule.step : Decimal.parse('0.01'),
    );
  }

  /// An intermediate slider position is a plain amount in the shown unit.
  void _onSliderAmount(String text) {
    final field = sizeUnit == OrderSizeUnit.base ? quantity : quoteAmount;
    if (_allocationPercent == null && field.text == text) return;
    field.text = text;
    ref.read(mainOrderAllocationProvider.notifier).manual();
    _render(() {});
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
    liveOrderDraftKey(rawDraft(null).withQuantity('')),
    sizeUnit,
    quantity.text,
    quoteAmount.text,
    attachment,
    entryPeg,
    widget.data.address,
    widget.data.symbol,
    _allocationPercent,
  );

  Future<void> _reviewAllocated({bool? direction}) async {
    if (direction != null && direction != buy) _render(() => buy = direction);
    final candidate = draft, terms = _formTerms, capturedSize = sizing;
    final controller = ref.read(mainOrderAllocationProvider.notifier);
    final review = await controller.prepare(
      candidate,
      isFormCurrent: () => mounted && _formTerms == terms,
      input: MainOrderReviewInput(
        draft: rawDraft(attaching ? LiveOrderAttachment(entryPeg: entryPeg) : null),
        size: _manualSizeInput,
        percent: _allocationPercent,
        attachment: attaching ? attachment : null,
      ),
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
      allocationReview: review,
    );
  }
}

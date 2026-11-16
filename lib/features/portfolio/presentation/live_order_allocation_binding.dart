part of 'live_order_form.dart';

/// Account facts that moved after the last read (fills, margin, settings).
/// A direction click re-reads and quotes again instead of stopping on these.
const _changedFacts = {
  'liveCapacityChanged',
  'liveCapacityStale',
  'liveOrderContextExpired',
  'liveAllocationChanged',
};

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

  Future<void> _reviewAllocated({bool? direction, bool retried = false}) async {
    if (direction != null && direction != buy) _render(() => buy = direction);
    final candidate = draft, terms = _formTerms, capturedSize = sizing;
    final controller = ref.read(mainOrderAllocationProvider.notifier);
    final review = await controller.prepare(
      candidate,
      isFormCurrent: () => mounted && _formTerms == terms,
      input: MainOrderReviewInput(
        // A retained BBO entry choice does not apply to a market entry.
        draft: rawDraft(attaching ? LiveOrderAttachment(entryPeg: market ? null : entryPeg) : null),
        size: _manualSizeInput,
        percent: _allocationPercent,
        attachment: attaching ? attachment : null,
      ),
    );
    if (!mounted) return;
    if (review == null) {
      if (_formTerms != terms) return;
      final failure = ref.read(mainOrderAllocationProvider).failure;
      controller.clearFailure();
      // The same unchanged form is quoted again after one full re-read.
      if (!retried && (failure == null || _changedFacts.contains(failure.key))) {
        final side = buy;
        if (!await _refreshForReview(side) || !mounted || _formTerms != terms) return;
        return _reviewAllocated(direction: side, retried: true);
      }
      // A clicked review reports its cause until dismissed, not inline where
      // the next background renewal would clear it.
      AppToast.showFailure(
        context,
        mainOrderAllocationFailureText(
          context,
          failure ?? const AccountReadFailure('liveAllocationChanged'),
          sizeUnit,
        ),
      );
      return;
    }
    final placed = await reviewLiveOrder(
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
      alwaysConfirm: _prefilled,
    );
    if (placed) _clearSize();
  }

  /// A placed order's size is not carried into the next one.
  void _clearSize() {
    if (!mounted) return;
    _render(() {
      quantity.clear();
      quoteAmount.clear();
      _ratioInput.clear();
    });
  }
}

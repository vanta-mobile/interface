part of 'live_order_form.dart';

/// Applies order inputs suggested from outside the form (deep links). They fill
/// an untouched main form once; the user still picks Long/Short, and this form
/// keeps the confirmation dialog on even when it was turned off.
extension _LiveOrderPrefillBinding on _LiveOrderFormState {
  void _watchPrefill() {
    final prefill = ref.watch(orderFormPrefillProvider);
    if (prefill == null || prefill.symbol != widget.data.symbol || _prefillScheduled) return;
    _prefillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillScheduled = false;
      if (mounted) _applyPrefill();
    });
  }

  /// Anything the user typed or chose wins; the suggestion is then dropped whole.
  bool get _untouched =>
      !_limitEdited &&
      quantity.text.trim().isEmpty &&
      quoteAmount.text.trim().isEmpty &&
      (_allocationPercent ?? 0) == 0 &&
      triggerPrice.text.trim().isEmpty &&
      trailingRate.text.trim().isEmpty &&
      attachment == null;

  void _applyPrefill() {
    final prefill = ref.read(orderFormPrefillProvider);
    if (prefill == null || prefill.symbol != widget.data.symbol) return;
    final allocation = ref.read(mainOrderAllocationProvider.notifier);
    // Reads, reviews and submissions finish first; the next build retries.
    if (!allocation.editable || ref.read(authProvider).busy) return;
    ref.read(orderFormPrefillProvider.notifier).clear();
    if (!_untouched) return;
    final mode = switch (prefill.type) {
      OrderPrefillType.limit => LiveOrderEntryMode.limit,
      OrderPrefillType.market => LiveOrderEntryMode.market,
      null => null,
    };
    _render(() {
      if (mode != null) _applyMode(mode);
      if (prefill.price case final value?) {
        price.text = value;
        _limitEdited = true;
        peg = null;
        entryPeg = null;
      }
      if (prefill.size case final size?) {
        sizeUnit = size.unit;
        (size.unit == OrderSizeUnit.base ? quantity : quoteAmount).text = size.text;
      }
      _prefilled = true;
    });
    if (prefill.size != null) allocation.manual();
    if (mode != null) widget.onModeChanged?.call(mode);
  }
}

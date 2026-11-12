import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'account_snapshot.dart';
import 'live_order.dart';
import 'live_order_capacity.dart';
import 'live_order_opening_cost.dart';
import 'live_order_size.dart';
import 'main_order_capacity.dart';
import 'main_order_price_assumption.dart';
import 'main_order_revaluation.dart';
import 'main_order_liquidation.dart';

/// Independent buy/sell estimates from one validated account/market snapshot.
/// Blank input has no order cost or notional; known zero capacity stays zero.
class MainOrderCapacityPreview {
  MainOrderCapacityPreview({
    required MainOrderCapacitySnapshot snapshot,
    required LiveOrderDraft draft,
    required OrderSizeUnit unit,
    required String input,
    int? percent,
    MainOrderRevaluation? valuation,
  }) : buy = _side(snapshot, draft.withDirection(true), unit, input, percent, valuation),
       sell = _side(snapshot, draft.withDirection(false), unit, input, percent, valuation);

  /// An editable manual intent can be previewed before signing for limits.
  /// Missing limits are unknown; this preview never supplies cost or capacity.
  MainOrderCapacityPreview.manual({
    required LiveOrderContext context,
    required LiveOrderDraft draft,
    required OrderSizeUnit unit,
    required String input,
  }) : buy = _manualSide(context, draft.withDirection(true), unit, input),
       sell = _manualSide(context, draft.withDirection(false), unit, input);
  MainOrderCapacityPreview.unavailable(AccountReadFailure failure)
    : buy = MainOrderSidePreview(failure: failure),
      sell = MainOrderSidePreview(failure: failure);
  final MainOrderSidePreview buy, sell;
}

MainOrderSidePreview _manualSide(
  LiveOrderContext context,
  LiveOrderDraft draft,
  OrderSizeUnit unit,
  String input,
) {
  if (input.trim().isEmpty) return const MainOrderSidePreview();
  if (draft.attachment?.entryPeg != null) {
    return const MainOrderSidePreview(
      failure: AccountReadFailure(
        'liveCapacityPriceUnavailable',
        reasonKey: 'livePriceDepthUnavailable',
      ),
    );
  }
  if (draft.reducing || draft.entireClose) {
    return const MainOrderSidePreview(failure: AccountReadFailure('liveCapacityPriceUnavailable'));
  }
  final size = LiveOrderSize(unit: unit, text: input).resolve(context, draft);
  final quantity = parseOrderDecimal(size.quantity);
  final invalid =
      size.failure ??
      context.rules.validate(
        draft.withQuantity(size.quantity),
        context.markPrice,
        pegReference: draft.peg == null ? null : context.referenceExecutionPrice(draft),
      );
  if (invalid != null || quantity == null || quantity <= Decimal.zero) {
    return MainOrderSidePreview(
      size: size,
      failure: AccountReadFailure(invalid ?? 'liveOrderInvalidQuantity'),
    );
  }
  final reference = context.referenceExecutionPrice(draft);
  if (draft.peg != null && (reference == null || reference <= Decimal.zero)) {
    return const MainOrderSidePreview(
      failure: AccountReadFailure(
        'liveCapacityPriceUnavailable',
        reasonKey: 'livePriceBookMissing',
      ),
    );
  }
  return MainOrderSidePreview(
    size: size,
    quantity: quantity,
    notional: reference == null ? null : quantity * reference,
  );
}

class MainOrderSidePreview {
  const MainOrderSidePreview({
    this.capacity,
    this.cost,
    this.quantity,
    this.notional,
    this.failure,
    this.size,
    this.liquidation,
  });
  final LiveOrderSideCapacity? capacity;
  final LiveOrderOpeningCost? cost;
  final Decimal? quantity, notional;
  final AccountReadFailure? failure;
  final OrderSizeResolution? size;
  final Rational? liquidation;
  String displayInput(OrderSizeUnit unit) => quantity == null
      ? ''
      : unit == OrderSizeUnit.base
      ? '$quantity'
      : size?.input?.toString() ?? '';
}

MainOrderSidePreview _side(
  MainOrderCapacitySnapshot snapshot,
  LiveOrderDraft draft,
  OrderSizeUnit unit,
  String input,
  int? percent,
  MainOrderRevaluation? valuation,
) {
  try {
    if (draft.reducing || draft.entireClose) {
      throw const AccountReadFailure('liveClosePositionChanged');
    }
    if (valuation != null && valuation.anchor != snapshot) {
      throw const AccountReadFailure('liveCapacityChanged');
    }
    final context = valuation?.context ?? snapshot.context;
    final prices = MainOrderPriceAssumption.resolve(context, draft);
    final reference = context.referenceExecutionPrice(draft);
    final (conversion, basis) = orderSizeReference(context, draft);
    if (reference == null || reference <= Decimal.zero) {
      throw const AccountReadFailure('liveCapacityPriceUnavailable');
    }
    final capacity = (valuation?.calculator(draft) ?? snapshot.calculator(draft)).side(
      buy: draft.buy,
      marginPrice: prices.margin,
      lossPrice: prices.loss,
      conversionPrice: conversion != null && conversion > Decimal.zero ? conversion : reference,
      notionalPrice: reference,
    );
    if (percent == 0 || percent == null && input.trim().isEmpty) {
      return MainOrderSidePreview(capacity: capacity);
    }
    final OrderSizeResolution size;
    if (percent != null) {
      if (unit == OrderSizeUnit.quote && (conversion == null || conversion <= Decimal.zero)) {
        return MainOrderSidePreview(
          capacity: capacity,
          failure: const AccountReadFailure('liveAmountReferenceUnavailable'),
        );
      }
      // The shown quote budget follows the whole-unit stop rule; base converts from it.
      final budget = unit == OrderSizeUnit.quote ? capacity.quoteAt(percent) : null;
      final amount = budget == null
          ? capacity.quantityAt(percent)
          : percent == 100
          ? capacity.maximum
          : capacity.quantityForQuote(budget);
      size = OrderSizeResolution(
        quantity: '$amount',
        input: budget,
        reference: unit == OrderSizeUnit.quote ? conversion : null,
        basis: unit == OrderSizeUnit.quote ? basis : null,
        referenceAt: orderSizeReferenceAt(context, basis),
        estimatedNotional: unit == OrderSizeUnit.quote ? amount * conversion! : null,
      );
    } else {
      size = LiveOrderSize(unit: unit, text: input).resolve(context, draft);
    }
    final quantity = parseOrderDecimal(size.quantity);
    if (size.failure != null || quantity == null || quantity <= Decimal.zero) {
      return MainOrderSidePreview(
        capacity: capacity,
        quantity: percent != null ? quantity : null,
        size: size,
        // A ratio stop that floors to zero is below one step, not a typo.
        failure: AccountReadFailure(
          size.failure ?? (percent != null ? 'liveAmountBelowStep' : 'liveOrderInvalidQuantity'),
        ),
      );
    }
    // Opposite-side protection exits may have been resolved for the selected
    // side. This panel estimates entry cost only; full strategy validation
    // remains on the actual selected draft in the submission flow.
    final validation = context.rules.validate(
      draft.withQuantity(size.quantity),
      context.markPrice,
      pegReference: draft.peg == null ? null : reference,
    );
    final cost = (valuation?.exposure ?? snapshot.exposure).cost(
      buy: draft.buy,
      quantity: quantity,
      marginPrice: prices.margin,
      lossPrice: prices.loss,
    );
    return MainOrderSidePreview(
      capacity: capacity,
      size: size,
      quantity: quantity,
      notional: quantity * reference,
      cost: cost,
      liquidation: validation == null && quantity <= capacity.maximum
          ? mainOrderLiquidation(
              snapshot: snapshot,
              valuation: valuation,
              context: context,
              draft: draft,
              quantity: quantity,
              cost: cost,
            )
          : null,
      failure: validation != null
          ? AccountReadFailure(validation)
          : quantity > capacity.maximum
          ? const AccountReadFailure('liveCapacityAboveMaximum')
          : null,
    );
  } on AccountReadFailure catch (failure) {
    return MainOrderSidePreview(failure: failure);
  } on ArgumentError {
    return const MainOrderSidePreview(failure: AccountReadFailure('accountDataInvalid'));
  }
}

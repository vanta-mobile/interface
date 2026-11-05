import 'package:decimal/decimal.dart';

import 'live_order_draft.dart';
import 'live_order_time_in_force.dart';

class OrderQuantityRule {
  const OrderQuantityRule({required this.minimum, required this.maximum, required this.step});
  final Decimal minimum, maximum, step;

  bool accepts(Decimal value) =>
      value >= minimum && value <= maximum && (value - minimum) % step == Decimal.zero;

  Decimal floor(Decimal value) {
    if (value < minimum) return Decimal.zero;
    return minimum + Decimal.fromBigInt(((value - minimum) / step).floor()) * step;
  }
}

class LiveOrderRules {
  LiveOrderRules({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.priceMinimum,
    required this.priceMaximum,
    required this.priceTick,
    required this.limitQuantity,
    required this.marketQuantity,
    required this.minimumNotional,
    required this.percentUp,
    required this.percentDown,
    required Set<LiveOrderTimeInForce> timeInForce,
    required Set<String> orderTypes,
    this.triggerProtect,
  }) : timeInForce = Set.unmodifiable(timeInForce),
       orderTypes = Set.unmodifiable(orderTypes);
  final String symbol, baseAsset, quoteAsset;
  final Decimal priceMinimum, priceMaximum, priceTick;
  final OrderQuantityRule limitQuantity, marketQuantity;
  final Decimal minimumNotional, percentUp, percentDown;
  final Set<LiveOrderTimeInForce> timeInForce;
  final Set<String> orderTypes;
  final Decimal? triggerProtect;
  Decimal? get triggerProtectPercent =>
      triggerProtect == null ? null : triggerProtect! * Decimal.fromInt(100);

  OrderQuantityRule quantityRule(LiveOrderDraft draft) =>
      draft.market && draft.trigger == null && draft.trailing == null
      ? marketQuantity
      : limitQuantity;

  bool acceptsPrice(Decimal price) =>
      !(priceMinimum > Decimal.zero && price < priceMinimum ||
          priceMaximum > Decimal.zero && price > priceMaximum ||
          priceTick > Decimal.zero && (price - priceMinimum) % priceTick != Decimal.zero);

  String? validate(LiveOrderDraft draft, Decimal markPrice, {bool exemptNotional = false}) {
    if (!draft.validPegShape) {
      return draft.peg == null ? 'attachedEntryPegInvalid' : 'liveOrderPegInvalid';
    }
    if (!draft.validQuickShape) return 'quickOrderInvalid';
    if (!draft.validTrailingShape) return 'liveTrailingInvalid';
    if (!draft.validEntireShape) return 'liveEntireInvalid';
    if (!orderTypes.contains(draft.orderType)) return 'liveOrderTypeUnavailable';
    if (!draft.market && !timeInForce.contains(draft.timeInForce)) {
      return 'liveOrderTimeInForceUnavailable';
    }
    final quantity = draft.entireClose ? null : parseOrderDecimal(draft.quantity);
    if (!draft.entireClose) {
      if (quantity == null || quantity <= Decimal.zero) return 'liveOrderInvalidQuantity';
      if (!quantityRule(draft).accepts(quantity)) return 'liveOrderQuantityFilter';
    }
    final pegged = draft.pegged;
    final price = pegged
        ? draft.trigger == null
              ? markPrice
              : parseOrderDecimal(draft.trigger!.price)
        : draft.market
        ? markPrice
        : parseOrderDecimal(draft.price);
    if (price == null || price <= Decimal.zero) return 'liveOrderInvalidPrice';
    if (!draft.market && !pegged && !acceptsPrice(price)) {
      return 'liveOrderPriceFilter';
    }
    if (!draft.market &&
        !pegged &&
        draft.trigger == null &&
        (draft.buy ? price > markPrice * percentUp : price < markPrice * percentDown)) {
      return 'liveOrderPercentFilter';
    }
    if (quantity != null && !exemptNotional && price * quantity < minimumNotional) {
      return 'liveOrderNotionalFilter';
    }
    if (draft.trailing case final trailing?) {
      final rate = parseOrderDecimal(trailing.callbackRate);
      if (rate == null || rate < Decimal.parse('0.1') || rate > Decimal.fromInt(5)) {
        return 'liveTrailingRateInvalid';
      }
      if (trailing.activationPrice case final text?) {
        final activation = parseOrderDecimal(text);
        if (activation == null || activation <= Decimal.zero) {
          return 'liveTrailingActivationInvalid';
        }
        if (!acceptsPrice(activation)) return 'liveTrailingActivationFilter';
      }
    }
    if (draft.trigger case final trigger?) {
      final stop = parseOrderDecimal(trigger.price);
      if (stop == null || stop <= Decimal.zero) return 'liveOrderInvalidTrigger';
      if (!acceptsPrice(stop)) return 'liveOrderTriggerFilter';
      if (trigger.protect && triggerProtect == null) return 'liveOrderProtectUnavailable';
    }
    return null;
  }
}

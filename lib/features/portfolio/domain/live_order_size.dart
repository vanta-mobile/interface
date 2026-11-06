import 'package:decimal/decimal.dart';

import 'live_order.dart';
import 'live_order_trigger.dart';

enum OrderSizeUnit { base, quote }

enum OrderSizeReference { limit, ask, bid, trigger, mark, last, bboMark }

/// Input conversion is a local estimate. Only the resolved base quantity enters
/// the immutable order draft, signer and recovery journal, never a quote budget.
class LiveOrderSize {
  const LiveOrderSize({required this.unit, required this.text});
  final OrderSizeUnit unit;
  final String text;

  OrderSizeResolution resolve(LiveOrderContext data, LiveOrderDraft entry) {
    if (entry.entireClose) return const OrderSizeResolution(quantity: '');
    if (unit == OrderSizeUnit.base) return OrderSizeResolution(quantity: text.trim());
    final input = parseOrderDecimal(text.trim());
    if (input == null || input <= Decimal.zero) {
      return const OrderSizeResolution(failure: 'liveAmountInvalid');
    }
    final (reference, basis) = orderSizeReference(data, entry);
    if (reference == null || reference <= Decimal.zero) {
      return const OrderSizeResolution(failure: 'liveAmountReferenceUnavailable');
    }
    final rule = data.rules.quantityRule(entry);
    if (rule.minimum < Decimal.zero ||
        rule.maximum <= Decimal.zero ||
        rule.maximum < rule.minimum ||
        rule.step <= Decimal.zero) {
      return const OrderSizeResolution(failure: 'accountDataInvalid');
    }
    // Keep repeating division rational until flooring the exact filter steps.
    final raw = input / reference;
    if (raw < rule.minimum.toRational()) {
      return const OrderSizeResolution(failure: 'liveAmountBelowStep');
    }
    final steps = ((raw - rule.minimum.toRational()) / rule.step.toRational()).floor();
    final quantity = rule.minimum + Decimal.fromBigInt(steps) * rule.step;
    if (quantity <= Decimal.zero) {
      return const OrderSizeResolution(failure: 'liveAmountBelowStep');
    }
    if (parseOrderDecimal('$quantity') == null || !rule.accepts(quantity)) {
      return const OrderSizeResolution(failure: 'liveOrderQuantityFilter');
    }
    return OrderSizeResolution(
      quantity: '$quantity',
      input: input,
      reference: reference,
      basis: basis,
      referenceAt: orderSizeReferenceAt(data, basis),
      estimatedNotional: quantity * reference,
    );
  }
}

class OrderSizeResolution {
  const OrderSizeResolution({
    this.quantity = '',
    this.failure,
    this.input,
    this.reference,
    this.basis,
    this.referenceAt,
    this.estimatedNotional,
  });
  final String quantity;
  final String? failure;
  final Decimal? input, reference, estimatedNotional;
  final OrderSizeReference? basis;
  final DateTime? referenceAt;
  bool get converted => input != null && failure == null;
}

/// The first valid Last snapshot seeds a limit input once. It is never silently
/// replaced with Mark or rounded into a different user-visible limit price.
String? initialLiveLimitPrice(LiveOrderContext data) {
  final last = data.lastPrice;
  return last != null && last > Decimal.zero && data.rules.acceptsPrice(last) ? '$last' : null;
}

/// Conversion reference shared by manual and percentage inputs. It remains
/// separate from the opening-cost execution/loss assumptions.
(Decimal?, OrderSizeReference) orderSizeReference(LiveOrderContext data, LiveOrderDraft entry) =>
    switch (entry) {
      LiveOrderDraft(peg: final peg?) => (
        data.referenceExecutionPrice(entry),
        peg.usesAsk(entry.buy) ? OrderSizeReference.ask : OrderSizeReference.bid,
      ),
      LiveOrderDraft(trigger: final trigger?, market: true) => (
        parseOrderDecimal(trigger.price),
        OrderSizeReference.trigger,
      ),
      LiveOrderDraft(trailing: final trailing?) => (
        trailing.basis == LiveOrderTriggerBasis.mark ? data.markPrice : data.lastPrice,
        trailing.basis == LiveOrderTriggerBasis.mark
            ? OrderSizeReference.mark
            : OrderSizeReference.last,
      ),
      LiveOrderDraft(pegged: true, trigger: final trigger?) => (
        parseOrderDecimal(trigger.price),
        OrderSizeReference.trigger,
      ),
      LiveOrderDraft(pegged: true) => (data.markPrice, OrderSizeReference.bboMark),
      LiveOrderDraft(market: false) => (parseOrderDecimal(entry.price), OrderSizeReference.limit),
      _ => (
        entry.buy ? data.ask : data.bid,
        entry.buy ? OrderSizeReference.ask : OrderSizeReference.bid,
      ),
    };

/// Label the actual quote receipt, without extending the private account lease.
DateTime orderSizeReferenceAt(LiveOrderContext data, OrderSizeReference basis) => switch (basis) {
  OrderSizeReference.ask || OrderSizeReference.bid => data.bookReceivedAt ?? data.receivedAt,
  OrderSizeReference.mark || OrderSizeReference.bboMark => data.markReceivedAt ?? data.receivedAt,
  OrderSizeReference.last => data.lastReceivedAt ?? data.receivedAt,
  OrderSizeReference.limit || OrderSizeReference.trigger => data.receivedAt,
};

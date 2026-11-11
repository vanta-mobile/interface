import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'futures_position_mode.dart';
import 'live_order.dart';
import 'live_order_time_in_force.dart';
import 'live_order_trigger.dart';
import 'order_query.dart';

String? validateAttachedOrder(LiveOrderContext data, LiveOrderDraft draft) {
  final attachment = draft.attachment;
  if (attachment == null) return null;
  if (draft.reducing ||
      draft.entireClose ||
      draft.trailing != null ||
      draft.quickEntry ||
      attachment.exits.isEmpty ||
      attachment.takeProfit?.kind == LiveOrderTriggerKind.stop ||
      attachment.stopLoss?.kind == LiveOrderTriggerKind.takeProfit) {
    return 'attachedOrderInvalid';
  }
  if (!draft.market && draft.timeInForce == LiveOrderTimeInForce.ioc) {
    return 'attachedOrderIocUnavailable';
  }
  if (!(data.mode == FuturesPositionMode.oneWay ? ['BOTH'] : ['LONG', 'SHORT']).every(
    data.positions.containsKey,
  )) {
    return 'attachedOrderPositionChanged';
  }
  final quantity = parseOrderDecimal(draft.quantity);
  if (quantity == null || quantity <= Decimal.zero) return 'attachedOrderNoExposure';
  if (!data.rules.limitQuantity.accepts(quantity)) return 'liveOrderQuantityFilter';
  for (final exit in attachment.exits) {
    if (!exit.validExecutionShape) return 'attachedOrderExecutionInvalid';
    final invalid = data.rules.validate(
      LiveOrderDraft(
        buy: !draft.buy,
        market: exit.market,
        quantity: '$quantity',
        price: exit.executionPrice ?? '',
        trigger: exit,
      ),
      data.markPrice,
      exemptNotional: data.mode == FuturesPositionMode.oneWay,
    );
    if (invalid != null) return invalid;
    // No local quote can prove the BBO entry's future resolved price. The
    // documented strategy-service bracket check is authoritative (including
    // HTTP 200 failureCode). Do not reject valid exits using a guessed level.
    if (attachment.entryPeg != null) continue;
    // A conditional/limit entry has its own future reference. Its exits remain
    // dormant until an entry fill, so current Last/Mark must not reject that bracket.
    final reference = attachedEntryReference(data, draft);
    if (reference == null || reference <= Decimal.zero) {
      return 'liveOrderTriggerReferenceUnavailable';
    }
    final stop = parseOrderDecimal(exit.price)!;
    if (exit.rises(!draft.buy) ? stop <= reference : stop >= reference) {
      return 'attachedOrderPriceDirection';
    }
  }
  return null;
}

extension AttachedOrderIntent on LiveOrderIntent {
  List<Map<String, String>> get strategyLegs => buildStrategyLegs(OrderQuery.capture(this));

  Map<String, String> get strategyParameters => {
    'clientStrategyId': clientOrderId,
    'strategyType': draft.attachment!.strategyType,
    'subOrderList': jsonEncode(strategyLegs),
  };
}

List<Map<String, String>> buildStrategyLegs(OrderQuery query) {
  final draft = query.draft, attachment = draft.attachment!;
  if (!draft.validPegShape) throw StateError('Invalid compound BBO shape');
  final symbol = query.symbol, side = query.side, positionSide = query.positionSide;
  final clientOrderId = query.clientOrderId, mode = query.mode;
  final entry = <String, String>{
    'strategySubId': '1',
    // The gateway requires explicit no-driver sentinels even though the
    // public table marks these linkage fields optional.
    'firstDrivenId': '0',
    'secondDrivenId': '0',
    'securityType': 'USDT_FUTURES',
    'symbol': symbol,
    'side': side,
    'positionSide': positionSide,
    'type': draft.orderType,
    'quantity': draft.quantity,
    'clientOrderId': '$clientOrderId-1',
    if (!draft.market) ...{
      'price': attachment.entryPeg == null ? draft.price : '0',
      'timeInForce': draft.timeInForce.wire,
      if (attachment.entryPeg case final peg?) 'pegPriceType': peg.wire,
    },
    if (draft.trigger case final trigger?) ...{
      'stopPrice': trigger.price,
      'workingType': trigger.basis.wire,
      'priceProtect': trigger.protect ? 'true' : 'false',
    },
  };
  return [
    entry,
    for (var i = 0; i < attachment.exits.length; i++)
      {
        'strategySubId': '${i + 2}',
        'securityType': 'USDT_FUTURES',
        'symbol': symbol,
        'side': draft.buy ? 'SELL' : 'BUY',
        'positionSide': positionSide,
        'type': attachment.exits[i].orderType(market: attachment.exits[i].market),
        'quantity': query.protectedQuantity!,
        'stopPrice': attachment.exits[i].price,
        if (!attachment.exits[i].market) ...{
          'price': attachment.exits[i].executionPrice!,
          'timeInForce': 'GTC',
        },
        'workingType': attachment.exits[i].basis.wire,
        'priceProtect': attachment.exits[i].protect ? 'true' : 'false',
        if (mode == FuturesPositionMode.oneWay) 'reduceOnly': 'true',
        'clientOrderId': '$clientOrderId-${i + 2}',
        'firstDrivenId': '1',
        'firstDrivenOn': attachment.drivenOn.wire,
        'firstTrigger': 'PLACE_ORDER',
        'secondDrivenId': attachment.exits.length == 2 ? '${i == 0 ? 3 : 2}' : '0',
        if (attachment.exits.length == 2) ...{
          'secondDrivenOn': attachment.drivenOn.wire,
          'secondTrigger': 'CANCEL_ORDER',
        },
      },
  ];
}

/// Indicative entry for exit calculations, never evidence of an actual fill.
Decimal? attachedEntryReference(LiveOrderContext data, LiveOrderDraft draft) {
  if (draft.market && draft.trigger == null) return draft.buy ? data.ask : data.bid;
  if (draft.market || draft.pegged) {
    return draft.trigger == null ? data.markPrice : parseOrderDecimal(draft.trigger!.price);
  }
  return parseOrderDecimal(draft.price);
}

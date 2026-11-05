import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import 'live_order.dart';

LiveOrderAttachment attachedProtection({
  bool buy = true,
  bool tp = true,
  bool sl = true,
  LiveOrderTriggerBasis basis = LiveOrderTriggerBasis.mark,
  bool protect = false,
  AttachedEntryPeg? peg,
}) => LiveOrderAttachment(
  entryPeg: peg,
  takeProfit: !tp
      ? null
      : AttachedExit(
          kind: LiveOrderTriggerKind.takeProfit,
          price: buy ? '81000' : '79000',
          basis: basis,
          protect: protect,
        ),
  stopLoss: !sl
      ? null
      : AttachedExit(
          kind: LiveOrderTriggerKind.stop,
          price: buy ? '79000' : '81000',
          basis: basis,
          protect: protect,
        ),
);

LiveOrderIntent attachedIntent({
  bool buy = true,
  bool hedge = false,
  bool market = false,
  bool tp = true,
  bool sl = true,
  String quantity = '0.001',
  AttachedEntryPeg? peg,
  LiveOrderContext? context,
  LiveOrderTimeInForce policy = LiveOrderTimeInForce.gtc,
  LiveOrderTrigger? trigger,
  LiveOrderAttachment? protection,
}) => LiveOrderIntent(
  context:
      context ??
      liveContext(
        bid: '80000',
        ask: '80000',
        mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
        positions: hedge
            ? {
                for (final side in ['LONG', 'SHORT'])
                  side: LiveOrderPosition(
                    side: side,
                    quantity: Decimal.zero,
                    entryPrice: Decimal.zero,
                  ),
              }
            : {},
      ),
  draft: liveDraft(
    buy: buy,
    market: market,
    quantity: quantity,
    price: peg == null ? '80000' : '',
    trigger: trigger,
    timeInForce: policy,
    attachment: protection ?? attachedProtection(buy: buy, tp: tp, sl: sl, peg: peg),
  ),
  clientOrderId: 'vanta-strategy-123',
  revision: 0,
);

/// Independent protocol fixture. No use of the production strategy builder.
Map<String, dynamic> attachedQuery(LiveOrderIntent intent) {
  final buy = intent.draft.buy, attachment = intent.draft.attachment!;
  return {
    'strategyId': 9876,
    'clientStrategyId': intent.clientOrderId,
    'strategyType': attachment.takeProfit != null && attachment.stopLoss != null ? 'OTOCO' : 'OTO',
    'strategyStatus': 'WORKING',
    'subOrders': [
      {
        'strategyId': 9876,
        'orderId': 100,
        'strategySubId': 1,
        'clientOrderId': '${intent.clientOrderId}-1',
        'status': 'NEW',
        'securityType': 'FUTURE',
        'symbol': 'BTCUSDT',
        'side': buy ? 'BUY' : 'SELL',
        'positionSide': intent.mode == FuturesPositionMode.oneWay
            ? 'BOTH'
            : buy
            ? 'LONG'
            : 'SHORT',
        'type':
            intent.draft.trigger?.orderType(market: intent.draft.market) ??
            (intent.draft.market ? 'MARKET' : 'LIMIT'),
        'quantity': intent.draft.quantity,
        'reduceOnly': false,
        'closePosition': false,
        'price': intent.draft.market || attachment.entryPeg != null ? '0' : intent.draft.price,
        if (attachment.entryPeg case final peg?) 'pegPriceType': peg.wire,
        'timeInForce': intent.draft.market ? 'GTC' : intent.draft.timeInForce.wire,
        'workingType': intent.draft.trigger?.basis.wire ?? 'CONTRACT_PRICE',
        'priceProtect': intent.draft.trigger?.protect ?? false,
        'stopPrice': intent.draft.trigger?.price ?? '0',
        'firstDrivenId': 0,
        'firstDrivenOn': '',
        'firstTrigger': '',
        'secondDrivenId': 0,
        'secondDrivenOn': '',
        'secondTrigger': '',
      },
      for (var i = 0; i < attachment.exits.length; i++)
        {
          'strategyId': 9876,
          'orderId': 0,
          'strategySubId': i + 2,
          'clientOrderId': '${intent.clientOrderId}-${i + 2}',
          'status': 'PENDING_NEW',
          'securityType': 'FUTURE',
          'symbol': 'BTCUSDT',
          'side': buy ? 'SELL' : 'BUY',
          'positionSide': intent.mode == FuturesPositionMode.oneWay
              ? 'BOTH'
              : buy
              ? 'LONG'
              : 'SHORT',
          'type': attachment.exits[i].kind == LiveOrderTriggerKind.takeProfit
              ? (attachment.exits[i].market ? 'TAKE_PROFIT_MARKET' : 'TAKE_PROFIT')
              : (attachment.exits[i].market ? 'STOP_MARKET' : 'STOP'),
          'quantity': intent.draft.quantity,
          'reduceOnly': intent.mode == FuturesPositionMode.oneWay,
          'closePosition': false,
          'price': attachment.exits[i].executionPrice ?? '0',
          'timeInForce': 'GTC',
          'workingType': attachment.exits[i].basis.wire,
          'priceProtect': attachment.exits[i].protect,
          'stopPrice': attachment.exits[i].price,
          'firstDrivenId': 1,
          'firstDrivenOn': attachment.drivenOn.wire,
          'firstTrigger': 'PLACE_ORDER',
          'secondDrivenId': attachment.exits.length == 2 ? (i == 0 ? 3 : 2) : 0,
          'secondDrivenOn': attachment.exits.length == 2 ? attachment.drivenOn.wire : '',
          'secondTrigger': attachment.exits.length == 2 ? 'CANCEL_ORDER' : '',
        },
    ],
  };
}

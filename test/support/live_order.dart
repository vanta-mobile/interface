import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order_funds.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import 'aster_account.dart';

import 'package:vanta/features/portfolio/domain/live_order_peg.dart';

import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';

final liveOrderClock = DateTime.utc(2026, 11, 3, 12);
Map<String, dynamic> liveExchangePayload() => {
  'symbols': [
    <String, dynamic>{
      'symbol': 'BTCUSDT',
      'status': 'TRADING',
      'contractType': 'PERPETUAL',
      'baseAsset': 'BTC',
      'quoteAsset': 'USDT',
      'marginAsset': 'USDT',
      'pricePrecision': 2,
      'orderTypes': [
        'LIMIT',
        'MARKET',
        'STOP',
        'STOP_MARKET',
        'TAKE_PROFIT',
        'TAKE_PROFIT_MARKET',
        'TRAILING_STOP_MARKET',
      ],
      'triggerProtect': '0.05',
      'timeInForce': ['GTC', 'IOC', 'GTX', 'HIDDEN'],
      'filters': <Map<String, dynamic>>[
        {'filterType': 'PRICE_FILTER', 'minPrice': '1', 'maxPrice': '1000000', 'tickSize': '0.1'},
        {'filterType': 'LOT_SIZE', 'minQty': '0.001', 'maxQty': '1000', 'stepSize': '0.001'},
        {'filterType': 'MARKET_LOT_SIZE', 'minQty': '0.001', 'maxQty': '120', 'stepSize': '0.001'},
        {'filterType': 'MIN_NOTIONAL', 'notional': '5'},
        {'filterType': 'PERCENT_PRICE', 'multiplierUp': '1.02', 'multiplierDown': '0.98'},
      ],
    },
  ],
};
LiveOrderContext liveContext({
  String address = accountAddress,
  FuturesPositionMode mode = FuturesPositionMode.oneWay,
  DateTime? time,
  Map<String, LiveOrderPosition> positions = const {},
  String? bid,
  String? ask,
  bool withFunds = true,
  String? available = '89.000000000000000001',
  FuturesAssetMode assetMode = FuturesAssetMode.single,
  bool? canTrade = true,
  Map<String, dynamic>? fundsPayload,
  AccountReadFailure? fundsFailure,
  Set<LiveOrderTimeInForce>? policies,
  Set<String>? orderTypes,
  String? lastPrice = '80001',
  String? protection = '0.05',
}) => LiveOrderContext(
  address: address,
  rules: mapLiveOrderRules({
    'symbols': [
      {
        ...(liveExchangePayload()['symbols'] as List).single as Map<String, dynamic>,
        if (policies != null) 'timeInForce': policies.map((value) => value.wire).toList(),
        if (orderTypes != null) 'orderTypes': orderTypes.toList(),
        'triggerProtect': protection,
      },
    ],
  }, 'BTCUSDT'),
  mode: mode,
  marginMode: PositionMarginMode.cross,
  leverage: 10,
  markPrice: Decimal.parse('80000'),
  lastPrice: lastPrice == null ? null : Decimal.parse(lastPrice),
  receivedAt: time ?? liveOrderClock,
  positions: positions.isEmpty && mode == FuturesPositionMode.oneWay
      ? {'BOTH': LiveOrderPosition(side: 'BOTH', quantity: Decimal.zero, entryPrice: Decimal.zero)}
      : positions,
  bid: bid == null ? null : Decimal.parse(bid),
  ask: ask == null ? null : Decimal.parse(ask),
  funds: !withFunds
      ? null
      : LiveOrderFunds(
          assetMode: assetMode,
          account: mapAsterAccount(
            fundsPayload ??
                {...accountPayload(), 'availableBalance': available, 'canTrade': canTrade},
            address: address,
            receivedAt: time ?? liveOrderClock,
          ),
        ),
  fundsFailure: fundsFailure,
);
LiveOrderDraft liveDraft({
  bool buy = true,
  bool market = false,
  String quantity = '0.001',
  String price = '80000',
  bool reduceOnly = false,
  String? closingSide,
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc,
  LiveOrderTrigger? trigger,
  bool entireClose = false,
  LiveOrderTrailing? trailing,
  bool quickEntry = false,
  LiveOrderAttachment? attachment,
  LiveOrderPeg? peg,
}) => LiveOrderDraft(
  buy: buy,
  market: market,
  quantity: quantity,
  price: price,
  reduceOnly: reduceOnly,
  closingSide: closingSide,
  timeInForce: timeInForce,
  trigger: trigger,
  entireClose: entireClose,
  trailing: trailing,
  quickEntry: quickEntry,
  attachment: attachment,
  peg: peg,
);

LiveOrderContext liveCloseContext({
  bool short = false,
  bool hedge = false,
  String quantity = '0.01',
}) {
  final side = hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH';
  return liveContext(
    mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
    positions: {
      side: LiveOrderPosition(
        side: side,
        quantity: Decimal.parse('${short ? '-' : ''}$quantity'),
        entryPrice: Decimal.parse('79000'),
      ),
    },
    bid: '79999',
    ask: '80001',
  );
}

LiveOrderIntent liveCloseIntent({
  bool short = false,
  bool hedge = false,
  bool market = true,
  String quantity = '0.005',
  bool reduceOnly = false,
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc,
  LiveOrderTrigger? trigger,
  bool entireClose = false,
  LiveOrderTrailing? trailing,
  LiveOrderPeg? peg,
}) => LiveOrderIntent(
  context: liveCloseContext(short: short, hedge: hedge),
  draft: liveDraft(
    buy: short,
    market: market,
    quantity: entireClose ? '' : quantity,
    price: entireClose || trailing != null || peg != null ? '' : '80000',
    peg: peg,
    entireClose: entireClose,
    trailing: trailing,
    reduceOnly: reduceOnly,
    timeInForce: timeInForce,
    trigger: trigger,
    closingSide: reduceOnly
        ? null
        : hedge
        ? (short ? 'SHORT' : 'LONG')
        : 'BOTH',
  ),
  clientOrderId: 'vanta-close-123',
  revision: 0,
);

List<Map<String, dynamic>> livePositionPayload(LiveOrderContext context) => [
  for (final side in context.mode == FuturesPositionMode.oneWay ? ['BOTH'] : ['LONG', 'SHORT'])
    {
      'symbol': context.symbol,
      'positionSide': side,
      'positionAmt': '${context.positions[side]?.quantity ?? Decimal.zero}',
      'entryPrice': '${context.positions[side]?.entryPrice ?? Decimal.zero}',
      'leverage': '${context.leverage}',
      'marginType': context.marginMode == PositionMarginMode.cross ? 'cross' : 'isolated',
    },
];
LiveOrderIntent liveIntent({
  bool market = false,
  bool buy = true,
  bool hedge = false,
  LiveOrderTimeInForce timeInForce = LiveOrderTimeInForce.gtc,
  LiveOrderTrigger? trigger,
  LiveOrderTrailing? trailing,
  LiveOrderPeg? peg,
}) => LiveOrderIntent(
  context: liveContext(mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay),
  draft: liveDraft(
    trailing: trailing,
    price: trailing == null && peg == null ? '80000' : '',
    peg: peg,
    market: market,
    buy: buy,
    timeInForce: timeInForce,
    trigger: trigger,
  ),
  clientOrderId: 'vanta-test-123',
  revision: 0,
);
Map<String, dynamic> liveQueryPayload(
  LiveOrderIntent intent, {
  String status = 'NEW',
  String? executed,
}) => {
  'symbol': intent.context.symbol,
  'clientOrderId': intent.clientOrderId,
  'orderId': 12345,
  'side': intent.side,
  'positionSide': intent.positionSide,
  'type': intent.draft.orderType,
  'origType': intent.draft.orderType,
  if (intent.draft.trigger case final trigger?) ...{
    'stopPrice': trigger.price,
    'workingType': trigger.basis.wire,
    'priceProtect': trigger.protect,
  },
  if (intent.draft.trailing case final trailing?) ...{
    'activatePrice': trailing.activationPrice ?? '80000',
    'priceRate': trailing.callbackRate,
    'workingType': trailing.basis.wire,
  },
  'status': status,
  'origQty': intent.draft.entireClose ? '0' : intent.draft.quantity,
  'executedQty':
      executed ??
      (status == 'FILLED' ? (intent.draft.entireClose ? '0.01' : intent.draft.quantity) : '0'),
  'price': intent.draft.market
      ? '0'
      : intent.draft.peg == null
      ? intent.draft.price
      : '80000',
  if (intent.draft.peg case final peg?) 'pegPriceType': peg.wire,
  'timeInForce': intent.draft.market ? 'GTC' : intent.draft.timeInForce.wire,
  'reduceOnly':
      !intent.draft.entireClose &&
      intent.draft.reducing &&
      intent.mode == FuturesPositionMode.oneWay,
  'closePosition': intent.draft.entireClose,
};

class TestLiveOrderRepository implements LiveOrderRepository {
  int reads = 0, submits = 0, checks = 0;
  Completer<void>? readGate, submitGate, checkGate;
  LiveOrderIntent? lastIntent;
  bool Function()? latestCurrent;
  AccountReadFailure? failure;
  bool throwAfterSubmit = false;
  bool? lastIncludeFunds;
  LiveOrderContext context = liveContext();
  LiveOrderResult result = LiveOrderResult(
    orderId: '12345',
    status: 'NEW',
    executedQuantity: Decimal.zero,
  );
  @override
  Future<LiveOrderContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
    bool includeFunds = true,
  }) async {
    reads++;
    lastIncludeFunds = includeFunds;
    latestCurrent = isCurrent;
    await readGate?.future;
    return context;
  }

  @override
  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) async {
    submits++;
    latestCurrent = isCurrent;
    lastIntent = intent;
    onStep(LiveOrderStep.signing);
    await submitGate?.future;
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    if (failure case final error? when !throwAfterSubmit) throw error;
    onStep(LiveOrderStep.submitting);
    if (failure case final error?) throw error;
    return result;
  }

  @override
  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) async {
    checks++;
    lastIntent = intent;
    onStep(LiveOrderStep.checkSigning);
    await checkGate?.future;
    return result;
  }
}

import 'package:decimal/decimal.dart';
import 'package:vanta/features/market/domain/mark_prices.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/data/capacity_account_mapper.dart';
import 'package:vanta/features/portfolio/domain/main_order_account_facts.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';

import 'aster_account.dart';
import 'live_order.dart';
import 'main_order_capacity.dart';

Decimal d(String n) => Decimal.parse(n);

final revaluationTiers = [
  MarginRiskTier(floor: d('0'), cap: d('1000'), rate: d('0.005'), cumulative: d('0')),
  MarginRiskTier(floor: d('1000'), cap: d('100000'), rate: d('0.01'), cumulative: d('5')),
];

MainOrderCapacitySnapshot withRevaluationFacts(
  MainOrderCapacitySnapshot base, {
  Map<String, dynamic>? payload,
  List<dynamic> orders = const [],
  Map<String, List<MarginRiskTier>>? tiers,
  Decimal? takerFee,
}) => MainOrderCapacitySnapshot(
  context: base.context,
  account: payload == null
      ? base.account
      : mapCapacityAccount(
          payload,
          address: base.context.address,
          receivedAt: base.account.receivedAt,
          units: capacityUnits(),
        ),
  assetMode: base.assetMode,
  availableMargin: base.availableMargin,
  exposure: base.exposure,
  notionalCap: base.notionalCap,
  contractCap: base.contractCap,
  receivedAt: base.receivedAt,
  marketFacts: MainOrderAccountFacts(
    orders: mapAsterOpenOrders(orders, address: accountAddress, receivedAt: base.receivedAt),
    takerFee: takerFee,
    riskTiers: tiers ?? {for (final symbol in capacityUnits().keys) symbol: revaluationTiers},
  ),
);

MarkPrices revaluationMarks(Map<String, String> prices, {DateTime? time}) => MarkPrices(
  connection: MarkPriceConnection.online,
  fresh: prices.keys.toSet(),
  quotes: {
    for (final e in prices.entries)
      e.key: MarkPriceQuote(
        symbol: e.key,
        price: d(e.value),
        eventTime: time ?? liveOrderClock,
        receivedAt: time ?? liveOrderClock,
      ),
  },
);

OrderReferencePrices revaluationReference({
  String symbol = 'BTCUSDT',
  String last = '100',
  String bid = '99',
  String ask = '101',
  DateTime? time,
}) => OrderReferencePrices(
  symbol: symbol,
  checkedAt: time ?? liveOrderClock,
  connection: OrderPriceConnection.online,
  tradeFresh: true,
  bookFresh: true,
  book: OrderBookQuote(
    symbol: symbol,
    bid: d(bid),
    ask: d(ask),
    eventTime: time ?? liveOrderClock,
    receivedAt: time ?? liveOrderClock,
  ),
  trade: OrderTradeQuote(
    symbol: symbol,
    price: d(last),
    tradeId: 1,
    eventTime: time ?? liveOrderClock,
    receivedAt: time ?? liveOrderClock,
  ),
);

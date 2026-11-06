import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_opening_cost.dart';
import 'package:vanta/features/portfolio/domain/live_order_rules.dart';

LiveOrderOpeningExposure openingExposure({
  String mark = '100',
  int leverage = 10,
  String position = '0',
  String bids = '0',
  String asks = '0',
  String? hedgeGross,
}) => hedgeGross != null
    ? LiveOrderOpeningExposure.hedge(
        markPrice: Decimal.parse(mark),
        leverage: leverage,
        grossNotional: Decimal.parse(hedgeGross),
      )
    : LiveOrderOpeningExposure.oneWay(
        markPrice: Decimal.parse(mark),
        leverage: leverage,
        positionQuantity: Decimal.parse(position),
        buyOrderNotional: Decimal.parse(bids),
        sellOrderNotional: Decimal.parse(asks),
      );

LiveOrderCapacity orderCapacity({
  LiveOrderOpeningExposure? exposure,
  String available = '100',
  String cap = '1000000',
  String? remaining,
  String minimum = '0.001',
  String maximum = '1000',
  String step = '0.001',
  String minimumNotional = '0',
}) => LiveOrderCapacity(
  exposure: exposure ?? openingExposure(),
  availableMargin: Decimal.parse(available).toRational(),
  notionalCap: Decimal.parse(cap),
  remainingOpenableNotional: remaining == null ? null : Decimal.parse(remaining),
  minimumNotional: Decimal.parse(minimumNotional),
  rule: OrderQuantityRule(
    minimum: Decimal.parse(minimum),
    maximum: Decimal.parse(maximum),
    step: Decimal.parse(step),
  ),
);

LiveOrderSideCapacity capacitySide(
  LiveOrderCapacity data, {
  bool buy = true,
  String margin = '100',
  String? loss,
  String? conversion,
  String? notional,
}) => data.side(
  buy: buy,
  marginPrice: Decimal.parse(margin),
  lossPrice: Decimal.parse(loss ?? margin),
  conversionPrice: Decimal.parse(conversion ?? margin),
  notionalPrice: Decimal.parse(notional ?? margin),
);

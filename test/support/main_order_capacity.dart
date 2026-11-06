import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/features/portfolio/domain/main_order_pricing.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/data/asset_index_repository.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/data/capacity_account_mapper.dart';
import 'package:vanta/features/portfolio/data/main_order_capacity_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_funds.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';

import 'aster_account.dart';
import 'live_order.dart';

Map<String, dynamic> capacityAsset({String asset = 'USDT'}) => {
  'asset': asset,
  'walletBalance': '150',
  'availableBalance': '100',
  'crossWalletBalance': '150',
  'crossUnPnl': '-5',
  'initialMargin': '50',
  'marginAvailable': true,
};

Map<String, dynamic> capacityPosition({
  String symbol = 'BTCUSDT',
  String side = 'BOTH',
  String quantity = '0',
  bool isolated = false,
  String orderMargin = '0',
}) => {
  'symbol': symbol,
  'positionSide': side,
  'positionAmt': quantity,
  'entryPrice': quantity == '0' ? '0' : '100',
  'notional': '${Decimal.parse(quantity) * Decimal.fromInt(100)}',
  'isolated': isolated,
  'leverage': '10',
  'openOrderInitialMargin': orderMargin,
  'maintMargin': '0',
  'maxNotional': '100000',
  'isolatedWallet': '0',
};

Map<String, dynamic> capacityAccountPayload({bool hedge = false, bool isolated = false}) => {
  'canTrade': true,
  'availableBalance': '999999',
  'assets': [capacityAsset()],
  'positions': hedge
      ? [
          capacityPosition(side: 'LONG', isolated: isolated),
          capacityPosition(side: 'SHORT', isolated: isolated),
        ]
      : [capacityPosition(isolated: isolated)],
};

Map<String, AsterContractUnits> capacityUnits() => {
  for (final base in ['BTC', 'ETH', 'SOL'])
    '${base}USDT': AsterContractUnits(base: base, quote: 'USDT', margin: 'USDT'),
};

LiveOrderContext capacityContext({
  bool hedge = false,
  bool isolated = false,
  FuturesAssetMode assetMode = FuturesAssetMode.single,
  Map<String, dynamic>? payload,
  DateTime? time,
}) {
  final raw = payload ?? capacityAccountPayload(hedge: hedge, isolated: isolated);
  return LiveOrderContext(
    address: accountAddress,
    receivedAt: time ?? liveOrderClock,
    rules: liveContext().rules,
    mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
    marginMode: isolated ? PositionMarginMode.isolated : PositionMarginMode.cross,
    leverage: 10,
    markPrice: Decimal.fromInt(100),
    bid: Decimal.fromInt(99),
    ask: Decimal.fromInt(101),
    positions: {
      for (final item in raw['positions'] as List)
        if ((item as Map)['symbol'] == 'BTCUSDT')
          item['positionSide'] as String: LiveOrderPosition(
            side: item['positionSide'] as String,
            quantity: Decimal.parse(item['positionAmt'] as String),
            entryPrice: Decimal.parse(item['entryPrice'] as String),
          ),
    },
    funds: LiveOrderFunds(
      assetMode: assetMode,
      account: mapAsterAccount(raw, address: accountAddress, receivedAt: time ?? liveOrderClock),
    ),
  );
}

Map<String, dynamic> capacityOrder({
  String side = 'BUY',
  String positionSide = 'BOTH',
  String type = 'LIMIT',
  String quantity = '3',
  String executed = '1',
  bool reduceOnly = false,
}) => {
  'symbol': 'BTCUSDT',
  'orderId': 10,
  'side': side,
  'positionSide': positionSide,
  'type': type,
  'status': 'PARTIALLY_FILLED',
  'time': liveOrderClock.millisecondsSinceEpoch,
  'origQty': quantity,
  'executedQty': executed,
  'price': type == 'LIMIT' ? '100' : '0',
  'reduceOnly': reduceOnly,
};

AssetIndexSnapshot capacityIndices({String usdtBid = '1', String usdtAsk = '1', DateTime? time}) =>
    mapAssetIndices([
      {
        'symbol': 'USDTUSD',
        'index': '1',
        'bidRate': usdtBid,
        'askRate': usdtAsk,
        'time': (time ?? liveOrderClock).millisecondsSinceEpoch,
      },
      {
        'symbol': 'BNBUSD',
        'index': '305',
        'bidRate': '300',
        'askRate': '310',
        'time': (time ?? liveOrderClock).millisecondsSinceEpoch,
      },
    ], receivedAt: liveOrderClock);

MainOrderCapacitySnapshot assembledCapacity({
  LiveOrderContext? context,
  Map<String, dynamic>? payload,
  List<dynamic> orders = const [],
  FuturesAssetMode? assetMode,
  FuturesPositionMode? positionMode,
  AssetIndexSnapshot? indices,
  SymbolOpenableNotional? contractCap,
  DateTime? now,
  DateTime? receivedAt,
  List<LeverageBracket>? brackets,
}) {
  final c = context ?? capacityContext();
  return assembleMainOrderCapacity(
    context: c,
    account: mapCapacityAccount(
      payload ?? capacityAccountPayload(),
      address: c.address,
      receivedAt: receivedAt ?? liveOrderClock,
      units: capacityUnits(),
    ),
    assetMode: assetMode ?? c.funds!.assetMode,
    positionMode: positionMode ?? c.mode,
    orders: mapAsterOpenOrders(
      orders,
      address: c.address,
      receivedAt: receivedAt ?? liveOrderClock,
    ),
    brackets:
        brackets ??
        [LeverageBracket(maximum: 20, floor: Decimal.zero, cap: Decimal.fromInt(100000))],
    contractCap:
        contractCap ??
        SymbolOpenableNotional(
          symbol: c.symbol,
          leverage: c.leverage,
          receivedAt: receivedAt ?? liveOrderClock,
          remaining: null,
        ),
    indices: indices,
    now: now ?? liveOrderClock,
  );
}

class TestCapacityRepository implements MainOrderCapacityRepository {
  int reads = 0;
  Completer<void>? gate;
  Object? failure;
  bool Function()? latestCurrent;
  void Function(AccountReadStep)? latestStep;
  MainOrderCapacitySnapshot Function(LiveOrderContext)? transform;

  @override
  Future<MainOrderCapacitySnapshot> read({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    latestStep = onStep;
    await gate?.future;
    if (failure case final error?) throw error;
    return transform?.call(context) ?? assembledCapacity(context: context);
  }
}

/// Existing form scenarios supply their own preflight context. Add an explicit
/// synthetic empty-order/risk snapshot using its balances and selected positions
/// so those scenarios exercise the new capacity guard without public HTTP.
class FixtureCapacityRepository extends TestCapacityRepository {
  FixtureCapacityRepository() {
    transform = (context) {
      final funds = context.funds!;
      final raw = <String, dynamic>{
        'canTrade': funds.account.canTrade ?? true,
        'assets': [
          for (final asset in funds.account.assets)
            {
              'asset': asset.asset,
              'availableBalance': '${asset.availableBalance ?? Decimal.zero}',
              'crossWalletBalance': '${asset.crossWalletBalance ?? asset.walletBalance}',
              'crossUnPnl': '${asset.crossUnrealizedProfit ?? Decimal.zero}',
              'initialMargin': '0',
              'marginAvailable': asset.marginAvailable ?? false,
            },
        ],
        'positions': [
          for (final p in context.positions.values)
            {
              ...capacityPosition(
                symbol: context.symbol,
                side: p.side,
                quantity: '${p.quantity}',
                isolated: context.marginMode == PositionMarginMode.isolated,
              ),
              'entryPrice': '${p.entryPrice}',
              'notional': '${p.quantity * context.markPrice}',
              'leverage': '${context.leverage}',
              'maxNotional': '1000000000',
            },
        ],
      };
      return assembledCapacity(
        context: context,
        payload: raw,
        indices: funds.assetMode == FuturesAssetMode.multi ? capacityIndices() : null,
        brackets: [
          LeverageBracket(
            maximum: context.leverage,
            floor: Decimal.zero,
            cap: Decimal.fromInt(1000000000),
          ),
        ],
      );
    };
  }
}

/// Legacy form/controller scenarios isolate the original bounded-price path.
/// Dedicated live-pricing tests use the production provider and controlled feeds.
MainOrderPricing fixtureBoundedPricing(Ref ref) => _FixtureBoundedPricing(ref);

class _FixtureBoundedPricing implements MainOrderPricing {
  _FixtureBoundedPricing(this.ref);
  final Ref ref;
  @override
  LiveOrderContext priceContext(LiveOrderContext anchor) => anchor;
  @override
  MainOrderRevaluation revalue(MainOrderCapacitySnapshot snapshot) => MainOrderRevaluation(
    anchor: snapshot,
    context: snapshot.context,
    availableMargin: snapshot.availableMargin,
    exposure: snapshot.exposure,
    checkedAt: ref.read(liveOrderClockProvider)(),
    assets: const {},
  );
}

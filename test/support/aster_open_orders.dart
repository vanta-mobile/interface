import 'dart:async';

import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';

import 'package:vanta/features/portfolio/domain/open_order_strategy.dart';

import 'aster_account.dart';

Map<String, Object?> openOrder({
  String symbol = 'BTCUSDT',
  int id = 1917641,
  String type = 'LIMIT',
  String status = 'NEW',
  String side = 'BUY',
  String positionSide = 'BOTH',
  String origQty = '0.40',
  String executedQty = '0',
  String price = '80000.01',
  int time = 1793620800000,
}) => {
  'symbol': symbol,
  'orderId': id,
  'type': type,
  'status': status,
  'side': side,
  'positionSide': positionSide,
  'origQty': origQty,
  'executedQty': executedQty,
  'price': price,
  'time': time,
  'updateTime': time,
  'timeInForce': 'GTC',
  'reduceOnly': false,
  'closePosition': false,
};

AsterOpenOrders openOrdersFixture({String address = accountAddress}) => mapAsterOpenOrders(
  [
    openOrder(),
    openOrder(
      symbol: 'ETHUSDT',
      id: 1917642,
      type: 'STOP_MARKET',
      status: 'PARTIALLY_FILLED',
      side: 'SELL',
      positionSide: 'LONG',
      origQty: '1.50',
      executedQty: '0.25',
      price: '0',
      time: 1793620801000,
    )..addAll({'stopPrice': '3000.50', 'workingType': 'MARK_PRICE'}),
  ],
  address: address,
  receivedAt: DateTime.utc(2026, 11, 2, 12, 30),
  units: const {
    'BTCUSDT': AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'),
    'ETHUSDT': AsterContractUnits(base: 'ETH', quote: 'USDT', margin: 'USDT'),
  },
);

class TestOpenOrdersRepository implements AsterOpenOrdersRepository {
  AsterOpenOrders result = openOrdersFixture();
  AccountReadFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<AsterOpenOrders> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    onStep(AccountReadStep.loading);
    if (failure case final error?) throw error;
    return result;
  }
}

class TestOpenOrderStrategyRepository implements OpenOrderStrategyRepository {
  OpenOrderStrategy? result;
  final queries = <OpenOrderStrategyQuery>[];
  @override
  Future<OpenOrderStrategy?> read({
    required String address,
    required AsterOpenOrder order,
    required OpenOrderStrategyQuery query,
    required bool Function() isCurrent,
  }) async {
    queries.add(query);
    return result;
  }
}

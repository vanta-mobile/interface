import 'dart:async';

import 'package:vanta/features/portfolio/data/spot_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';
import 'package:vanta/features/portfolio/domain/spot_open_orders.dart';

import 'aster_account.dart';

const spotOrderTime = 1793779200000;
Map<String, dynamic> spotOpenOrderPayload({
  String symbol = 'BTCUSDT',
  String id = '9007199254740993',
}) => {
  'symbol': symbol,
  'orderId': id,
  'clientOrderId': 'original-$id',
  'side': 'BUY',
  'type': 'LIMIT',
  'status': 'NEW',
  'price': '80000.000000000000000001',
  'avgPrice': '0',
  'origQty': '0.100000000000000001',
  'executedQty': '0',
  'cumQuote': '0',
  'timeInForce': 'GTC',
  'stopPrice': '0',
  'origType': 'LIMIT',
  'time': spotOrderTime,
  'updateTime': spotOrderTime,
};
const spotOrderUnits = {
  'BTCUSDT': SpotSymbolUnits(base: 'BTC', quote: 'USDT'),
  'ETHUSDT': SpotSymbolUnits(base: 'ETH', quote: 'USDT'),
};
SpotOpenOrders spotOrdersFixture({
  String address = accountAddress,
  DateTime? receivedAt,
  Iterable<Map<String, dynamic>>? rows,
}) => mapSpotOpenOrders(
  (rows ?? [spotOpenOrderPayload(), spotOpenOrderPayload(symbol: 'ETHUSDT', id: '7')]).toList(),
  address: address,
  receivedAt: receivedAt ?? DateTime.now().toUtc(),
  units: spotOrderUnits,
);

class TestSpotOpenOrdersRepository implements SpotOpenOrdersRepository {
  SpotOpenOrders? result;
  Object? failure;
  Completer<void>? gate;
  int calls = 0;
  bool Function()? current;
  @override
  Future<SpotOpenOrders> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    current = isCurrent;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (failure case final e?) throw e;
    onStep(AccountReadStep.loading);
    return result ?? spotOrdersFixture(address: address);
  }
}

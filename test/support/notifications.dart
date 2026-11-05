import 'package:vanta/features/notifications/data/spot_notification_mapper.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';

import 'dart:async';

import 'package:vanta/features/notifications/data/futures_notification_mapper.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/data/notification_units_repository.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import 'open_order_updates.dart';

class MemoryNotificationStorage implements NotificationStorage {
  String? value;
  bool failRead = false, failWrite = false;
  int reads = 0, writes = 0;
  Completer<void>? readGate, writeGate;
  @override
  Future<String?> read() async {
    reads++;
    final saved = value;
    await readGate?.future;
    if (failRead) throw StateError('sensitive transport detail');
    return saved;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    await writeGate?.future;
    if (failWrite) throw StateError('sensitive storage detail');
    this.value = value;
  }
}

class TestNotificationUnitsRepository implements NotificationUnitsRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, AsterContractUnits>> read() async {
    calls++;
    if (fail) throw StateError('public metadata unavailable');
    return const {
      'BTCUSDT': AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'),
      'ETHUSDT': AsterContractUnits(base: 'ETH', quote: 'USDT', margin: 'USDT'),
    };
  }
}

Map<String, dynamic> notificationOrderPayload({
  int tradeId = 42,
  String filled = '0.1',
  String last = '0.1',
  String status = 'PARTIALLY_FILLED',
  int time = orderEventClock,
}) {
  final payload = orderUpdatePayload(filled: filled, status: status, eventTime: time);
  final order = payload['o'] as Map<String, dynamic>;
  order['t'] = tradeId;
  order['l'] = last;
  return payload;
}

OrderNotification notificationOrder({
  int tradeId = 42,
  String filled = '0.1',
  String last = '0.1',
  String status = 'PARTIALLY_FILLED',
  int time = orderEventClock,
}) =>
    mapFuturesNotification(
          notificationOrderPayload(
            tradeId: tradeId,
            filled: filled,
            last: last,
            status: status,
            time: time,
          ),
        )!
        as OrderNotification;

Map<String, dynamic> marginNotificationPayload({int time = orderEventClock}) => {
  'e': 'MARGIN_CALL',
  'E': time,
  'cw': '3.16812045',
  'p': <Map<String, dynamic>>[
    {
      's': 'ETHUSDT',
      'ps': 'LONG',
      'pa': '1.327',
      'mt': 'CROSSED',
      'iw': '0',
      'mp': '187.17127',
      'up': '-1.166074',
      'mm': '1.614445',
    },
    {
      's': 'BTCUSDT',
      'ps': 'SHORT',
      'pa': '-0.001',
      'mt': 'ISOLATED',
      'iw': '-0.2',
      'mp': '80000.00000001',
      'up': '-0.000000001',
      'mm': '0.0001',
    },
  ],
};
MarginNotification marginNotification() =>
    mapFuturesNotification(marginNotificationPayload())! as MarginNotification;

Map<String, dynamic> spotNotificationPayload({
  int tradeId = 42,
  int time = orderEventClock,
  String status = 'PARTIALLY_FILLED',
  String filled = '0.1',
  String last = '0.1',
}) => {
  'e': 'executionReport',
  'E': time,
  'T': time - 1,
  's': 'BTCUSDT',
  'c': 'spot-test-1',
  'i': '1917641',
  'S': 'BUY',
  'o': 'LIMIT',
  'ot': 'LIMIT',
  'q': '0.4',
  'p': '80000.01',
  'ap': filled == '0' ? '0' : '80000.01',
  'x': status == 'NEW'
      ? 'NEW'
      : status == 'CANCELED'
      ? 'CANCELED'
      : 'TRADE',
  'X': status,
  'l': last,
  'z': filled,
  'L': last == '0' ? '0' : '80000.01',
  't': tradeId,
  'Y': last == '0' ? '0' : '8000.001',
  'Z': filled == '0' ? '0' : '8000.001',
  'n': '0.000000000000000001',
  'N': 'BNB',
  'O': 0,
  'P': '0',
  'Q': '0',
};
SpotOrderNotification spotNotification({int tradeId = 42, int time = orderEventClock}) =>
    mapSpotNotification(spotNotificationPayload(tradeId: tradeId, time: time));

class TestSpotNotificationUnitsRepository implements SpotNotificationUnitsRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, SpotSymbolUnits>> read() async {
    calls++;
    if (fail) throw StateError('untrusted metadata failure');
    // Deliberately differs from futures to prove that each market owns its units.
    return const {'BTCUSDT': SpotSymbolUnits(base: 'SPOT_BTC', quote: 'SPOT_USDT')};
  }
}

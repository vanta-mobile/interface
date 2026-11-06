import 'dart:async';

import 'package:http/testing.dart';
import 'package:vanta/features/market/data/aster_service.dart';

final orderPriceClock = DateTime.utc(2026, 11, 6, 12);
Map<String, Object?> orderBookPayload({
  String symbol = 'BTCUSDT',
  int? time,
  String bid = '99.123456789123456789',
  String ask = '101.123456789123456789',
}) => {
  'symbol': symbol,
  'bidPrice': bid,
  'askPrice': ask,
  'bidQty': '1',
  'askQty': '2',
  'time': time ?? orderPriceClock.millisecondsSinceEpoch,
};
Map<String, Object?> orderBookEvent({
  String symbol = 'BTCUSDT',
  int id = 100,
  int? time,
  String bid = '99.123456789123456789',
  String ask = '101.123456789123456789',
}) => {
  'e': 'bookTicker',
  's': symbol,
  'u': id,
  'E': time ?? orderPriceClock.millisecondsSinceEpoch,
  'T': time ?? orderPriceClock.millisecondsSinceEpoch,
  'b': bid,
  'B': '1',
  'a': ask,
  'A': '2',
};
List<Map<String, Object?>> orderTradePayload({
  int id = 200,
  int? time,
  String price = '100.123456789123456789',
}) => [
  {'id': id, 'price': price, 'qty': '1', 'time': time ?? orderPriceClock.millisecondsSinceEpoch},
];
Map<String, Object?> orderTradeEvent({
  String symbol = 'BTCUSDT',
  int id = 201,
  int? time,
  String price = '100.123456789123456789',
}) => {
  'e': 'aggTrade',
  's': symbol,
  'a': 100,
  'f': id - 1,
  'l': id,
  'p': price,
  'q': '1',
  'E': time ?? orderPriceClock.millisecondsSinceEpoch,
  'T': time ?? orderPriceClock.millisecondsSinceEpoch,
};

class TestOrderPriceService extends AsterService {
  TestOrderPriceService() : super(MockClient((_) => throw StateError('Unexpected HTTP')));
  DateTime now = orderPriceClock;
  final requests = <(String, Map<String, String>?)>[];
  final clocks = <Completer<Object?>>[],
      books = <Completer<Object?>>[],
      trades = <Completer<Object?>>[];
  final controllers = <StreamController<Map<String, Object?>>>[];
  final channels = <List<String>>[];
  int cancelled = 0;
  @override
  Stream<Map<String, Object?>> stream(List<String> streams) {
    channels.add(List.of(streams));
    final controller = StreamController<Map<String, Object?>>(onCancel: () => cancelled++);
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Object?> request(String path, [Map<String, String>? query]) {
    requests.add((path, query));
    final target = switch (path) {
      '/fapi/v3/time' => clocks,
      '/fapi/v3/ticker/bookTicker' => books,
      '/fapi/v3/trades' => trades,
      _ => throw StateError('Unexpected path'),
    };
    final gate = Completer<Object?>();
    target.add(gate);
    return gate.future;
  }

  Future<void> connect([int index = 0]) async {
    controllers[index].add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    clocks.last.complete({'serverTime': now.millisecondsSinceEpoch});
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> seed() async {
    await connect();
    books.last.complete(orderBookPayload(time: now.millisecondsSinceEpoch));
    trades.last.complete(orderTradePayload(time: now.millisecondsSinceEpoch));
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    for (final controller in controllers) {
      await controller.close();
    }
    client.close();
  }
}

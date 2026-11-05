import 'dart:async';

import 'package:http/testing.dart';
import 'package:vanta/features/market/data/aster_service.dart';

final markClock = DateTime.utc(2026, 11, 3, 12);
Map<String, Object?> markPayload({
  String symbol = 'BTCUSDT',
  String price = '81000.123456789123456789',
  int? time,
}) => {'symbol': symbol, 'markPrice': price, 'time': time ?? markClock.millisecondsSinceEpoch};
Map<String, Object?> markEvent({
  String symbol = 'BTCUSDT',
  String price = '82000.123456789123456789',
  int? time,
}) => {
  'e': 'markPriceUpdate', 's': symbol, 'p': price, 'E': time ?? markClock.millisecondsSinceEpoch,
  'c': '999999', // Last price is deliberately unrelated and must never be read.
};

class TestMarkService extends AsterService {
  TestMarkService() : super(MockClient((_) => throw StateError('unexpected HTTP request')));
  DateTime now = markClock;
  final controllers = <StreamController<Map<String, Object?>>>[];
  final snapshots = <Completer<Object?>>[];
  final channels = <List<String>>[];
  int cancelled = 0;
  @override
  int get serverNow => now.millisecondsSinceEpoch;
  @override
  Stream<Map<String, Object?>> stream(List<String> streams) {
    channels.add(streams);
    final controller = StreamController<Map<String, Object?>>(onCancel: () => cancelled++);
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Object?> request(String path, [Map<String, String>? query]) {
    if (path != '/fapi/v3/premiumIndex' || query != null) throw StateError('unexpected request');
    final gate = Completer<Object?>();
    snapshots.add(gate);
    return gate.future;
  }

  Future<void> dispose() async {
    for (final controller in controllers) {
      await controller.close();
    }
    client.close();
  }
}

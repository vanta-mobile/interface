import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:vanta/features/market/application/market_sync.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/domain/market.dart';

Candle candle(int minute, {bool closed = true}) => Candle(
  time: minute * 60000,
  open: 100,
  high: 120,
  low: 90,
  close: 110,
  volume: 2,
  closed: closed,
);
Map<String, Object?> live(String symbol, int minute, int event, {bool closed = false}) => {
  'e': 'kline',
  'E': event,
  'k': {
    's': symbol,
    'i': '1m',
    't': minute * 60000,
    'o': '100',
    'h': '120',
    'l': '90',
    'c': '115',
    'v': '3',
    'x': closed,
  },
};

class FakeAster extends AsterService {
  FakeAster() : super(MockClient((_) => throw StateError('Unexpected HTTP')));
  final events = StreamController<Map<String, Object?>>.broadcast();
  final requests = <({String symbol, int? start, int limit})>[];
  int active = 0, maximum = 0, currentMinute = 199;
  bool listening = false;
  int latency = 1;
  Completer<void>? historyGate, tickerGate;
  int tickerRequests = 0;
  @override
  Future<Map<String, Map<String, Object?>>> refreshTickers({String? symbol}) async {
    tickerRequests++;
    await tickerGate?.future;
    return {};
  }

  @override
  int get serverNow => currentMinute * 60000 + 30000;
  @override
  Stream<Map<String, Object?>> stream(List<String> streams) {
    expect(streams, ['coin88usdt@kline_1m']);
    expect(streams.every((e) => e.endsWith('@kline_1m')), true);
    listening = true;
    scheduleMicrotask(() => events.add({'connected': true}));
    return events.stream;
  }

  @override
  Future<List<Candle>> history(
    String symbol,
    String interval, {
    int? start,
    int? end,
    int limit = 200,
  }) async {
    expect(listening, true, reason: 'Realtime subscription must start before REST');
    requests.add((symbol: symbol, start: start, limit: limit));
    maximum = math.max(maximum, ++active);
    await historyGate?.future;
    await Future<void>.delayed(Duration(milliseconds: latency));
    active--;
    final first = start == null ? 0 : math.max(0, start ~/ 60000);
    final last = end == null ? 199 : math.min(currentMinute, end ~/ 60000);
    return [
      for (var i = first; i <= last && i < first + limit; i++) candle(i, closed: i < currentMinute),
    ];
  }
}

List<AsterInstrument> instruments() => List.generate(
  100,
  (i) => AsterInstrument(
    symbol: 'COIN${i}USDT',
    base: 'COIN$i',
    ticker: {'openPrice': '100', 'highPrice': '120', 'lowPrice': '90', 'quoteVolume': '10000'},
    precision: const MarketPrecision(priceTick: '0.00000001', quantityStep: '0.05'),
  ),
);
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 500; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Synchronization did not settle');
}

void main() {
  test(
    'page refresh joins active history and waits for ticker without scheduling another load',
    () async {
      final service = FakeAster()
        ..historyGate = Completer<void>()
        ..tickerGate = Completer<void>();
      final sync = MarketSync(service, instruments()[88], '1m');
      addTearDown(() async {
        await sync.dispose();
        await service.events.close();
        service.client.close();
      });
      sync.start();
      await until(() => service.requests.isNotEmpty);
      var completed = false;
      final refresh = sync.refresh().then((_) => completed = true);
      await until(() => service.tickerRequests == 1);
      service.historyGate!.complete();
      await until(() => sync.overview.repairing == 0);
      expect(completed, false);
      expect(service.requests, hasLength(1));
      service.tickerGate!.complete();
      await refresh;
      expect(completed, true);
      expect(service.requests, hasLength(1));
    },
  );
  test(
    'loads only its chart, preserves live updates, and paginates a long reconnect gap',
    () async {
      final service = FakeAster();
      final sync = MarketSync(service, instruments()[88], '1m');
      addTearDown(() async {
        await sync.dispose();
        await service.events.close();
        service.client.close();
      });
      sync.start();
      service.events.add(live('COIN88USDT', 199, 100));
      await until(() => sync.overview.loaded == 1 && sync.overview.repairing == 0);
      expect(service.maximum, lessThanOrEqualTo(5));
      expect(sync.overview.total, 1);
      expect(sync.market('COIN88USDT')!.precision.priceTick, '0.00000001');
      expect(sync.market('COIN88USDT')!.precision.quantityStep, '0.05');
      expect(sync.series.candles.last.close, 115);
      expect(sync.overview.failed, 0);
      expect(service.requests, hasLength(1), reason: 'Do not re-query every initial boundary');
      service.currentMinute = 2200;
      service.events.add({'disconnected': true});
      service.events.add(live('COIN88USDT', 2200, 200));
      service.events.add({'connected': true});
      await until(
        () =>
            sync.overview.repairing == 0 &&
            service.requests.any((r) => r.symbol == 'COIN88USDT' && (r.start ?? 0) > 1000 * 60000),
      );
      final target = sync.series;
      expect(target.missingRange, null);
      expect(target.candles, hasLength(600));
      expect(target.candles.last.time, 2200 * 60000);
      expect(target.candles.last.close, 115, reason: 'Current WS state must survive REST repair');
      expect(
        service.requests.any((r) => r.symbol == 'COIN88USDT' && r.start == 199 * 60000),
        true,
        reason: 'Include the last known bar when repairing a gap',
      );
    },
  );
  test('disposed interval session cannot publish late historical responses', () async {
    final service = FakeAster()..latency = 50;
    final sync = MarketSync(service, instruments()[88], '1m')..start();
    await until(() => service.active > 0);
    await sync.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(sync.initialized, false);
    await service.events.close();
    service.client.close();
  });
}

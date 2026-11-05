import 'dart:async';
import 'dart:math' as math;

import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/domain/candle_series.dart';
import 'package:vanta/features/market/domain/market.dart';

final testInstruments = List.generate(
  100,
  (i) => AsterInstrument(
    symbol: i == 0 ? 'BTCUSDT' : 'COIN${i}USDT',
    base: i == 0 ? 'BTC' : 'COIN$i',
    ticker: {'openPrice': '100', 'highPrice': '200', 'lowPrice': '50', 'quoteVolume': '10000'},
  ),
);

class TestMarketService extends AsterService {
  TestMarketService() : super(MockClient((_) => throw StateError('Unexpected HTTP')));
  final requests = <({SeriesKey key, int? start, int? end, int limit})>[];
  final completedInitials = <SeriesKey>{};
  final connections = <({SeriesKey key, StreamController<Map<String, Object?>> events})>[];
  final tickerRequests = <String?>[];
  bool autoConnect = true, failRequests = false;
  int active = 0, maximum = 0, activeStreams = 0, maximumStreams = 0;
  Completer<void>? gate;
  int now = 1793343600000;
  int? earliestTime;
  @override
  int get serverNow => now;

  @override
  Stream<Map<String, Object?>> stream(List<String> streams) {
    final interval = streams.first.split('@kline_').last;
    if (streams.length != 1) {
      throw StateError('Expected only the visible chart stream');
    }
    late StreamController<Map<String, Object?>> controller;
    controller = StreamController<Map<String, Object?>>.broadcast(
      onListen: () {
        activeStreams++;
        maximumStreams = math.max(maximumStreams, activeStreams);
        if (autoConnect) scheduleMicrotask(() => controller.add({'connected': true}));
      },
      onCancel: () => activeStreams--,
    );
    connections.add((
      key: SeriesKey(streams.single.split('@').first.toUpperCase(), interval),
      events: controller,
    ));
    return controller.stream;
  }

  @override
  Future<List<Candle>> history(
    String symbol,
    String interval, {
    int? start,
    int? end,
    int limit = 200,
  }) async {
    final key = SeriesKey(symbol, interval);
    requests.add((key: key, start: start, end: end, limit: limit));
    maximum = math.max(maximum, ++active);
    try {
      final blocker = gate;
      if (blocker != null) {
        await blocker.future;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      if (failRequests) throw const MarketFailure('Aster HTTP 503');
      final last = candleOpenAt(interval, end ?? now);
      final first = start ?? key.shift(last, -(limit - 1));
      final close = 110.0 + quickCandleIntervals.indexOf(interval);
      final result = [
        for (
          var time = first, count = 0;
          time <= last && count < limit;
          time = key.shift(time), count++
        )
          if (earliestTime == null || time >= earliestTime!)
            Candle(
              time: time,
              open: 100,
              high: 200,
              low: 50,
              close: close,
              volume: 2,
              closed: key.shift(time) <= now,
            ),
      ];
      if (start == null) completedInitials.add(key);
      return result;
    } finally {
      active--;
    }
  }

  @override
  Future<Map<String, Map<String, Object?>>> refreshTickers({String? symbol}) async {
    tickerRequests.add(symbol);
    return {
      for (final instrument in testInstruments)
        if (symbol == null || instrument.symbol == symbol) instrument.symbol: instrument.ticker,
    };
  }

  Future<void> close() async {
    if (gate case final blocker? when !blocker.isCompleted) blocker.complete();
    await Future.wait(connections.map((c) => c.events.close()));
    client.close();
  }
}

Future<void> waitForMarket(bool Function() ready) async {
  for (var i = 0; i < 400; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Market did not settle');
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/shared_market_streams.dart';

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('equivalent channel sets share a socket and replay connection to late listeners', () async {
    var opened = 0, cancelled = 0;
    final source = StreamController<Map<String, Object?>>(onCancel: () => cancelled++);
    final streams = SharedMarketStreams((channels) {
      opened++;
      expect(channels, ['mark', 'trade']);
      return source.stream;
    });
    final first = <Map<String, Object?>>[], second = <Map<String, Object?>>[];
    final a = streams.stream(['mark', 'trade']).listen(first.add);
    source.add({'connected': true});
    source.add({'e': 'markPriceUpdate', 's': 'BTCUSDT'});
    await _turn();
    final b = streams.stream(['trade', 'mark', 'mark']).listen(second.add);
    await _turn();
    expect(opened, 1);
    expect(second, [
      {'connected': true},
    ]); // Old ticks are never replayed as fresh.
    source.add({'e': 'markPriceUpdate', 's': 'ETHUSDT'});
    await _turn();
    expect(first.last['s'], 'ETHUSDT');
    expect(second.last['s'], 'ETHUSDT');
    expect(() => second.last['s'] = 'MUTATED', throwsUnsupportedError);
    await a.cancel();
    expect(cancelled, 0);
    await b.cancel();
    expect(cancelled, 1);
    await streams.dispose();
    await source.close();
  });

  test('disconnect/reconnect state reaches all consumers and late subscribers', () async {
    final source = StreamController<Map<String, Object?>>();
    final streams = SharedMarketStreams((_) => source.stream);
    final first = <Map<String, Object?>>[], second = <Map<String, Object?>>[];
    final a = streams.stream(['mark']).listen(first.add);
    source.add({'connected': true});
    source.add({'disconnected': true});
    await _turn();
    final b = streams.stream(['mark']).listen(second.add);
    await _turn();
    expect(second.single, {'disconnected': true});
    source.add({'connected': true});
    await _turn();
    expect(first.last, {'connected': true});
    expect(second.last, {'connected': true});
    await a.cancel();
    await b.cancel();
    await streams.dispose();
    await source.close();
  });

  test('last unsubscribe evicts entry; a new consumer opens a new subscription', () async {
    final sources = <StreamController<Map<String, Object?>>>[];
    final streams = SharedMarketStreams((_) {
      final source = StreamController<Map<String, Object?>>();
      sources.add(source);
      return source.stream;
    });
    final a = streams.stream(['mark']).listen((_) {});
    await a.cancel();
    final events = <Map<String, Object?>>[];
    final b = streams.stream(['mark']).listen(events.add);
    expect(sources.length, 2);
    await _turn();
    expect(events, isEmpty);
    await b.cancel();
    await streams.dispose();
    for (final source in sources) {
      await source.close();
    }
  });

  test('different channels remain independent and pool disposal closes every consumer', () async {
    final sources = <StreamController<Map<String, Object?>>>[];
    var cancelled = 0, done = 0;
    final streams = SharedMarketStreams((_) {
      final source = StreamController<Map<String, Object?>>(onCancel: () => cancelled++);
      sources.add(source);
      return source.stream;
    });
    streams.stream(['mark']).listen((_) {}, onDone: () => done++);
    streams.stream(['trade']).listen((_) {}, onDone: () => done++);
    expect(sources.length, 2);
    await streams.dispose();
    await _turn();
    expect(cancelled, 2);
    expect(done, 2);
    expect(await streams.stream(['mark']).toList(), isEmpty);
    for (final source in sources) {
      await source.close();
    }
  });

  test('an upstream error invalidates the replayed connection state', () async {
    final source = StreamController<Map<String, Object?>>();
    final streams = SharedMarketStreams((_) => source.stream);
    final a = streams.stream(['mark']).listen((_) {}, onError: (Object _) {});
    source.add({'connected': true});
    source.addError(StateError('offline'));
    await _turn();
    final late = <Map<String, Object?>>[];
    final b = streams.stream(['mark']).listen(late.add);
    await _turn();
    expect(late.single, {'disconnected': true});
    await a.cancel();
    await b.cancel();
    await streams.dispose();
    await source.close();
  });
}

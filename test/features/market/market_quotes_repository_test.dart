import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:vanta/features/market/data/market_quotes_repository.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';
import 'package:vanta/features/market/domain/market_descriptor.dart';

final instruments = [
  AsterInstrument(
    symbol: 'BTCUSDT',
    base: 'BTC',
    descriptor: MarketDescriptor(name: 'Bitcoin', aliases: ['比特币'], categories: ['Top', 'AI']),
    ticker: {
      'lastPrice': '100',
      'priceChangePercent': '1',
      'quoteVolume': '1200',
      'lastFundingRate': '0.0001',
    },
  ),
  AsterInstrument(
    symbol: 'ETHUSDT',
    base: 'ETH',
    ticker: {
      'lastPrice': '200',
      'priceChangePercent': '-2',
      'quoteVolume': '2400',
      'lastFundingRate': '-0.0002',
    },
  ),
];

Map<String, Object?> ticker(int time, String price, {String symbol = 'BTCUSDT'}) => {
  'e': '24hrTicker',
  'E': time,
  's': symbol,
  'c': price,
  'P': '0',
  'q': '9876543.123456789',
};
Map<String, Object?> funding(int time, String rate) => {
  'e': 'markPriceUpdate', 'E': time, 's': 'BTCUSDT', 'r': rate,
  // The mark price must never replace last trade price.
  'p': '999999',
};
Map<String, Map<String, Object?>> snapshot(String price) => {
  for (final instrument in instruments)
    instrument.symbol: {
      ...instrument.ticker,
      if (instrument.symbol == 'BTCUSDT') 'lastPrice': price,
    },
};

void main() {
  test('refresh waits for resumed scope snapshot when previous scope is still settling', () async {
    final service = QuoteService();
    final repository = MarketQuotesRepository(service, instruments);
    final subscription = repository.events.listen((_) {});
    addTearDown(() async {
      await subscription.cancel();
      await repository.dispose();
      await service.close();
    });
    service.events.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    expect(service.snapshots, hasLength(1));
    await repository.setActive(false);
    await repository.setActive(true);
    service.events.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    var completed = false;
    final refresh = repository.refresh().then((_) => completed = true);
    service.snapshots.first.complete(snapshot('90'));
    await Future<void>.delayed(Duration.zero);
    expect(service.snapshots, hasLength(2));
    expect(completed, false);
    service.snapshots.last.complete(snapshot('150'));
    await refresh;
    expect(repository.state.quotes.first.price, Decimal.fromInt(150));
    expect(completed, true);
  });
  test('merges deltas by symbol with Decimal precision and batches list updates', () async {
    final service = QuoteService();
    final repository = MarketQuotesRepository(service, instruments);
    final emissions = <MarketQuotes>[];
    final subscription = repository.events.listen(emissions.add);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.connection, QuoteConnection.connecting);
    expect(service.channels.single, ['!ticker@arr', '!markPrice@arr@1s']);
    expect(repository.state.updatedAt, null);
    service.events.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    service.snapshots.single.complete(snapshot('101'));
    await Future<void>.delayed(Duration.zero);
    final baseline = emissions.length;
    service.events.add(ticker(100, '0.0000010203'));
    service.events.add(funding(90, '-0.000345'));
    service.events.add(ticker(200, '300', symbol: 'UNLISTEDUSDT'));
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(baseline));
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(emissions, hasLength(baseline + 1));
    final result = repository.state;
    expect(result.quotes.map((q) => q.symbol), ['BTCUSDT', 'ETHUSDT']);
    expect(result.quotes.first.price, Decimal.parse('0.0000010203'));
    expect(result.quotes.first.change, Decimal.zero);
    expect(result.quotes.first.quoteVolume, Decimal.parse('9876543.123456789'));
    expect(result.quotes.first.funding, Decimal.parse('-0.000345'));
    expect(result.quotes.first.descriptor.name, 'Bitcoin');
    expect(result.quotes.first.descriptor.aliases, ['比特币']);
    expect(result.quotes.first.descriptor.categories, {'Top', 'AI'});
    expect(result.quotes.last.price, Decimal.fromInt(200));
    expect(result.connection, QuoteConnection.live);
    expect(result.updatedAt, isNotNull);
    expect(() => result.quotes.clear(), throwsUnsupportedError);
    await subscription.cancel();
    await repository.dispose();
    await service.close();
    expect(service.cancelled, 1);
  });

  test('older or malformed deltas cannot overwrite a usable field', () async {
    final service = QuoteService();
    final repository = MarketQuotesRepository(service, instruments);
    final subscription = repository.events.listen((_) {});
    service.events.add(ticker(100, '123'));
    service.events.add(ticker(90, '99'));
    service.events.add(funding(200, '0.0008'));
    service.events.add(funding(150, '-0.05'));
    service.events.add(ticker(300, 'NaN'));
    service.events.add({...ticker(400, '456'), 'q': '-1'});
    service.events.add({...funding(300, 'Infinity')});
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes.first.price, Decimal.fromInt(123));
    expect(repository.state.quotes.first.funding, Decimal.parse('0.0008'));
    expect(repository.state.failure, QuoteFailure.data);
    await subscription.cancel();
    await repository.dispose();
    await service.close();
  });

  test('late snapshots merge unaffected symbols without overwriting newer stream fields', () async {
    final service = QuoteService();
    final repository = MarketQuotesRepository(service, instruments);
    final subscription = repository.events.listen((_) {});
    service.events.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    service.events.add(ticker(100, '123'));
    service.events.add(funding(100, '-0.0007'));
    await Future<void>.delayed(Duration.zero);
    service.snapshots.single.complete({
      ...snapshot('90'),
      'ETHUSDT': {...instruments.last.ticker, 'lastPrice': '250'},
    });
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes.first.price, Decimal.fromInt(123));
    expect(repository.state.quotes.first.funding, Decimal.parse('-0.0007'));
    expect(repository.state.quotes.last.price, Decimal.fromInt(250));
    expect(repository.state.refreshing, false);
    await subscription.cancel();
    await repository.dispose();
    await service.close();
  });

  test(
    'disconnect and failed reconnect snapshots retain values and report recovery state',
    () async {
      final service = QuoteService();
      final repository = MarketQuotesRepository(service, instruments);
      final subscription = repository.events.listen((_) {});
      service.events.add({'connected': true});
      await Future<void>.delayed(Duration.zero);
      service.snapshots.single.complete(snapshot('101'));
      service.events.add(ticker(100, '123'));
      service.events.add(funding(100, '0.0008'));
      await Future<void>.delayed(Duration.zero);
      final asOf = repository.state.updatedAt;
      service.events.add({'disconnected': true});
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.connection, QuoteConnection.offline);
      expect(repository.state.updatedAt, asOf);
      expect(repository.state.quotes.first.price, Decimal.fromInt(123));
      service.events.add({'connected': true});
      await Future<void>.delayed(Duration.zero);
      expect(service.snapshots, hasLength(2));
      expect(repository.state.connection, QuoteConnection.connecting);
      service.snapshots.last.completeError(StateError('private upstream payload'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.failure, QuoteFailure.snapshot);
      expect(repository.state.quotes.first.price, Decimal.fromInt(123));
      service.events.add(ticker(200, '124'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.connection, QuoteConnection.partial);
      service.events.add(funding(200, '0'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.connection, QuoteConnection.live);
      await subscription.cancel();
      await repository.dispose();
      await service.close();
    },
  );

  test('background suspends transport, resume resyncs, and disposal rejects late work', () async {
    final service = QuoteService();
    final repository = MarketQuotesRepository(service, instruments);
    final emissions = <MarketQuotes>[];
    final subscription = repository.events.listen(emissions.add);
    service.events.add({'connected': true});
    service.events.add(ticker(100, '123'));
    await Future<void>.delayed(Duration.zero);
    await repository.setActive(false);
    expect(service.cancelled, 1);
    expect(repository.state.connection, QuoteConnection.offline);
    service.snapshots.first.complete(snapshot('90'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.quotes.first.price, Decimal.fromInt(123));
    await repository.setActive(true);
    expect(service.channels, hasLength(2));
    service.events.add({'connected': true});
    await Future<void>.delayed(Duration.zero);
    expect(service.snapshots, hasLength(2));
    await subscription.cancel();
    await repository.dispose();
    final count = emissions.length;
    service.snapshots.last.complete(snapshot('70'));
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(emissions, hasLength(count));
    expect(service.channels, hasLength(2));
    expect(service.cancelled, 2);
    await service.close();
  });

  test('live status expires independently for ticker and funding streams', () async {
    final service = QuoteService();
    var now = DateTime(2026, 11, 2, 12);
    final repository = MarketQuotesRepository(service, instruments, now: () => now);
    final subscription = repository.events.listen((_) {});
    service.events.add({'connected': true});
    service.events.add(ticker(100, '123'));
    service.events.add(funding(100, '0.0001'));
    await Future<void>.delayed(Duration.zero);
    service.snapshots.single.complete(snapshot('101'));
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 36));
    service.events.add(ticker(200, '124'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.connection, QuoteConnection.partial);
    expect(repository.state.quotes.first.funding, Decimal.parse('0.0001'));
    service.events.add(funding(200, '0.0002'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.connection, QuoteConnection.live);
    await subscription.cancel();
    await repository.dispose();
    await service.close();
  });
}

class QuoteService extends AsterService {
  QuoteService() : super(MockClient((_) => throw StateError('Unexpected request')));
  final sockets = <StreamController<Map<String, Object?>>>[];
  final channels = <List<String>>[];
  final snapshots = <Completer<Map<String, Map<String, Object?>>>>[];
  int cancelled = 0;
  StreamController<Map<String, Object?>> get events => sockets.last;

  @override
  Stream<Map<String, Object?>> stream(List<String> streams) {
    channels.add(List.of(streams));
    final controller = StreamController<Map<String, Object?>>(onCancel: () => cancelled++);
    sockets.add(controller);
    return controller.stream;
  }

  @override
  Future<Map<String, Map<String, Object?>>> refreshTickers({String? symbol}) {
    if (symbol != null) throw StateError("Expected a list snapshot");
    final result = Completer<Map<String, Map<String, Object?>>>();
    snapshots.add(result);
    return result.future;
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    client.close();
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selection_providers.dart' show symbolProvider, intervalProvider;
import '../../../core/market_failure.dart';
import '../domain/market.dart';
import '../domain/market_quotes.dart';
import '../data/aster_service.dart';
import '../data/market_quotes_repository.dart';
import '../data/market_http_client.dart';
import 'market_sync.dart';
import 'market_sessions.dart';

final asterServiceProvider = Provider<AsterService>((ref) {
  final client = createMarketHttpClient();
  ref.onDispose(client.close);
  return AsterService(client);
});
final instrumentsProvider = FutureProvider<List<AsterInstrument>>(
  (ref) => ref.watch(asterServiceProvider).instruments(),
);
final quoteUpdatesActiveProvider = NotifierProvider<QuoteUpdatesActive, bool>(
  QuoteUpdatesActive.new,
);

class QuoteUpdatesActive extends Notifier<bool> {
  @override
  bool build() => true;
  void setActive(bool active) => state = active;
}

final quoteReconnectProvider = NotifierProvider<QuoteReconnect, int>(QuoteReconnect.new);

class QuoteReconnect extends Notifier<int> {
  @override
  int build() => 0;
  void reconnect() => state++;
}

// Only the selector and Markets destination watch this provider. Its socket
// and timers are disposed as soon as the last quote-list consumer closes.
final marketQuotesRepositoryProvider = Provider.autoDispose<MarketQuotesRepository?>((ref) {
  final instruments = ref.watch(instrumentsProvider);
  if (instruments.value == null) return null;
  final repository = MarketQuotesRepository(
    ref.watch(asterServiceProvider),
    instruments.requireValue,
    active: ref.read(quoteUpdatesActiveProvider),
  );
  ref.listen(quoteUpdatesActiveProvider, (_, active) => unawaited(repository.setActive(active)));
  ref.listen(quoteReconnectProvider, (_, _) => unawaited(repository.reconnect()));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final liveMarketQuotesProvider = StreamProvider.autoDispose<MarketQuotes>(retry: (_, _) => null, (
  ref,
) {
  final repository = ref.watch(marketQuotesRepositoryProvider);
  if (repository != null) return repository.events;
  final instruments = ref.watch(instrumentsProvider);
  return instruments.hasError
      ? Stream.error(instruments.error!, instruments.stackTrace)
      : const Stream.empty();
});
final selectedInstrumentProvider = Provider<AsterInstrument?>((ref) {
  final symbol = ref.watch(symbolProvider);
  return ref.watch(instrumentsProvider).value?.where((i) => i.symbol == symbol).firstOrNull;
});
final selectedPrecisionProvider = Provider<MarketPrecision>(
  (ref) => ref.watch(selectedInstrumentProvider)?.precision ?? const MarketPrecision(),
);
final marketSessionsProvider = Provider<MarketSessions?>((ref) {
  final instruments = ref.watch(instrumentsProvider).value;
  if (instruments == null) return null;
  final sessions = MarketSessions(ref.watch(asterServiceProvider), instruments);
  ref.onDispose(() => unawaited(sessions.dispose()));
  return sessions;
});
final marketSyncProvider = Provider<MarketSync?>((ref) {
  final sessions = ref.watch(marketSessionsProvider);
  final interval = ref.watch(intervalProvider);
  final symbol = ref.watch(symbolProvider);
  return sessions?.select(interval, symbol);
});
final syncOverviewProvider = StreamProvider<SyncOverview>((ref) {
  final instruments = ref.watch(instrumentsProvider);
  final sync = ref.watch(marketSyncProvider);
  if (sync == null) {
    return instruments.hasError
        ? Stream.error(instruments.error!, instruments.stackTrace)
        : const Stream.empty();
  }
  return Stream.multi((output) {
    final subscription = sync.updates.listen((_) => output.add(sync.overview));
    output.onCancel = subscription.cancel;
    output.add(sync.overview);
  });
});
final asterMarketProvider = StreamProvider<Market>(retry: (_, _) => null, (ref) {
  final symbol = ref.watch(symbolProvider);
  final instruments = ref.watch(instrumentsProvider);
  final sync = ref.watch(marketSyncProvider);
  if (sync == null) {
    return instruments.hasError
        ? Stream.error(instruments.error!, instruments.stackTrace)
        : const Stream.empty();
  }
  // MarketSync owns timed retries. Keep stream errors visible instead of
  // Riverpod automatically restarting them as another loading state.
  return Stream.multi((output) {
    void publish() {
      final market = sync.market(symbol);
      if (market != null) {
        output.add(market);
      } else if (sync.failure != null) {
        output.addError(MarketFailure(sync.failure!));
      }
    }

    final subscription = sync.updates.listen((changed) {
      if (changed.contains(symbol)) publish();
    });
    output.onCancel = subscription.cancel;
    publish();
  });
});
final currentMarketProvider = Provider<Market?>((ref) {
  final data = ref.watch(asterMarketProvider);
  final symbol = ref.watch(symbolProvider);
  final interval = ref.watch(intervalProvider);
  final value = data.value;
  if (!data.isLoading && value?.symbol == symbol && value?.interval == interval) return value;
  // A synchronous cache read avoids blanking a chart while the StreamProvider
  // attaches to the newly selected interval. Never reuse another interval.
  return ref.watch(marketSyncProvider)?.market(symbol);
});
final chartHistoryProvider = NotifierProvider<ChartHistoryController, void>(
  ChartHistoryController.new,
);

class ChartHistoryController extends Notifier<void> {
  @override
  void build() {}
  Future<void> loadOlder() async => ref.read(marketSyncProvider)?.loadOlder();
}

final asterBookProvider = StreamProvider.autoDispose<OrderBook>((ref) async* {
  final symbol = ref.watch(symbolProvider).toLowerCase();
  final service = ref.watch(asterServiceProvider);
  List<BookLevel> bids = [], asks = [];
  final trades = <MarketTrade>[];
  var lastEmission = 0;
  var depthConnected = false;
  await for (final event in service.bookStream(symbol)) {
    if (event['connected'] == true) {
      if (event['channel'] == 'depth') depthConnected = true;
      continue;
    }
    if (event['disconnected'] == true) {
      if (event['channel'] == 'depth') depthConnected = false;
      yield OrderBook(
        asks: asks,
        bids: bids,
        trades: List.unmodifiable(trades),
        connected: depthConnected,
      );
      continue;
    }
    if (event['e'] == 'depthUpdate') {
      List<BookLevel> levels(Object? raw, bool reverse) =>
          ((raw as List<dynamic>)
              .map((r) {
                final row = r as List<dynamic>;
                return BookLevel(AsterService.numeric(row[0]), AsterService.numeric(row[1]));
              })
              .where((l) => l.quantity > 0)
              .toList()
            ..sort((a, b) => reverse ? b.price.compareTo(a.price) : a.price.compareTo(b.price)));
      bids = levels(event['b'], true);
      asks = levels(event['a'], false);
    } else if (event['e'] == 'aggTrade') {
      trades.insert(
        0,
        MarketTrade(
          price: AsterService.numeric(event['p']),
          quantity: AsterService.numeric(event['q']),
          buy: event['m'] == false,
          time: (event['T'] as num).toInt(),
        ),
      );
      if (trades.length > 30) trades.removeLast();
    } else {
      continue;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastEmission >= 250) {
      lastEmission = now;
      yield OrderBook(
        asks: asks,
        bids: bids,
        trades: List.unmodifiable(trades),
        connected: depthConnected,
      );
    }
  }
});

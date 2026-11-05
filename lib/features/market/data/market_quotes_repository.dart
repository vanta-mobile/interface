import 'dart:async';

import 'package:decimal/decimal.dart';

import '../domain/market_quote.dart';
import '../domain/market_quotes.dart';
import 'aster_service.dart';
import 'market_quote_mapper.dart';

/// Merges public quote deltas without changing the chart's instrument universe.
class MarketQuotesRepository {
  MarketQuotesRepository(
    this.service,
    List<AsterInstrument> instruments, {
    this._active = true,
    DateTime Function()? now,
  }) : _quotes = {
         for (final instrument in instruments) instrument.symbol: mapMarketQuote(instrument),
       },
       _now = now ?? DateTime.now {
    _output = StreamController<MarketQuotes>(onListen: _start, onCancel: _stop);
  }

  final AsterService service;
  final DateTime Function() _now;
  final Map<String, MarketQuote> _quotes;
  final _versions = <(String, bool), int>{};
  final _eventTimes = <(String, bool), int>{};
  late final StreamController<MarketQuotes> _output;
  StreamSubscription<Map<String, Object?>>? _subscription;
  Timer? _publishTimer, _freshnessTimer;
  bool _active, _disposed = false, _connected = false, _connecting = true;
  bool _refreshing = false, _refreshAgain = false;
  DateTime? _tickerAt, _fundingAt, _updatedAt;
  QuoteFailure? _failure;
  int _epoch = 0;

  Stream<MarketQuotes> get events => _output.stream;

  MarketQuotes get state {
    final now = _now();
    bool recent(DateTime? time) => time != null && now.difference(time).inSeconds < 35;
    final tickerLive = recent(_tickerAt), fundingLive = recent(_fundingAt);
    return MarketQuotes(
      quotes: _quotes.values,
      connection: !_active || (!_connected && !_connecting)
          ? QuoteConnection.offline
          : !_connected
          ? QuoteConnection.connecting
          : tickerLive && fundingLive
          ? QuoteConnection.live
          : tickerLive || fundingLive
          ? QuoteConnection.partial
          : QuoteConnection.connecting,
      updatedAt: _updatedAt,
      failure: _failure,
      refreshing: _refreshing,
    );
  }

  void _publish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!_disposed && _output.hasListener) _output.add(state);
  }

  void _schedulePublish() {
    _publishTimer ??= Timer(const Duration(milliseconds: 250), _publish);
  }

  void _start() {
    _publish();
    if (!_active || _disposed || _subscription != null) return;
    _connecting = true;
    final epoch = ++_epoch;
    _subscription = service
        .stream(['!ticker@arr', '!markPrice@arr@1s'])
        .listen(
          (event) {
            if (!_disposed && epoch == _epoch) _onEvent(event);
          },
          onError: (Object _) {
            if (!_disposed && epoch == _epoch) _disconnected();
          },
          onDone: () {
            if (!_disposed && epoch == _epoch) _disconnected();
          },
        );
    _freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) => _publish());
  }

  void _disconnected() {
    _connected = false;
    _connecting = false;
    _tickerAt = _fundingAt = null;
    _publish();
  }

  Future<void> _stop() async {
    _epoch++;
    _freshnessTimer?.cancel();
    _publishTimer?.cancel();
    _publishTimer = null;
    final subscription = _subscription;
    _subscription = null;
    _connected = false;
    _tickerAt = _fundingAt = null;
    await subscription?.cancel();
  }

  Future<void> setActive(bool active) async {
    if (_disposed || _active == active) return;
    _active = active;
    if (active) {
      _start();
    } else {
      final stopping = _stop();
      _publish();
      await stopping;
    }
  }

  Future<void> reconnect() async {
    if (_disposed || !_active) return;
    await _stop();
    if (!_disposed && _active) _start();
  }

  void _onEvent(Map<String, Object?> event) {
    if (event['connected'] == true) {
      _connected = true;
      _publish();
      unawaited(_refresh());
      return;
    }
    if (event['disconnected'] == true) {
      _disconnected();
      return;
    }
    final funding = event['e'] == 'markPriceUpdate';
    if (!funding && event['e'] != '24hrTicker') return;
    final symbol = event['s'];
    final quote = _quotes[symbol];
    final time = event['E'];
    if (quote == null || time is! int || time < 0) return;
    final key = (quote.symbol, funding);
    if (time < (_eventTimes[key] ?? -1)) return;
    final fields = funding
        ? {'lastFundingRate': event['r']}
        : {'lastPrice': event['c'], 'priceChangePercent': event['P'], 'quoteVolume': event['q']};
    // Bad deltas never replace a usable value with a fabricated zero.
    if (fields.entries.any((entry) => !_valid(entry.key, entry.value))) {
      _failure = QuoteFailure.data;
      _schedulePublish();
      return;
    }
    _eventTimes[key] = time;
    _versions[key] = (_versions[key] ?? 0) + 1;
    _quotes[quote.symbol] = _merge(quote, fields);
    final now = _now();
    if (funding) {
      _fundingAt = now;
    } else {
      _tickerAt = now;
    }
    _updatedAt = now;
    _schedulePublish();
  }

  bool _valid(String key, Object? raw) {
    final value = Decimal.tryParse('$raw');
    return value != null && (key != 'lastPrice' && key != 'quoteVolume' || value >= Decimal.zero);
  }

  MarketQuote _merge(MarketQuote current, Map<String, Object?> fields) {
    Decimal? value(String key, Decimal? previous) =>
        fields.containsKey(key) ? Decimal.tryParse('${fields[key]}') : previous;
    return MarketQuote(
      symbol: current.symbol,
      base: current.base,
      precision: current.precision,
      descriptor: current.descriptor,
      price: value('lastPrice', current.price),
      change: value('priceChangePercent', current.change),
      quoteVolume: value('quoteVolume', current.quoteVolume),
      funding: value('lastFundingRate', current.funding),
    );
  }

  Future<void> _refresh() async {
    if (_disposed || !_active) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    _refreshAgain = false;
    _publish();
    final epoch = _epoch;
    final versions = Map.of(_versions);
    try {
      final snapshot = await service.refreshTickers();
      if (_disposed || epoch != _epoch || !_active) return;
      var any = false;
      var invalid = _quotes.keys.any((symbol) => !snapshot.containsKey(symbol));
      for (final entry in snapshot.entries) {
        final current = _quotes[entry.key];
        if (current == null) continue;
        final fields = <String, Object?>{};
        for (final key in ['lastPrice', 'priceChangePercent', 'quoteVolume', 'lastFundingRate']) {
          final group = (entry.key, key == 'lastFundingRate');
          // A delayed HTTP response cannot overwrite a delta received since
          // its request began. Funding and trade fields have separate versions.
          if ((_versions[group] ?? 0) != (versions[group] ?? 0)) continue;
          final raw = entry.value[key];
          if (!_valid(key, raw)) {
            invalid = true;
            continue;
          }
          fields[key] = raw;
        }
        if (fields.isNotEmpty) {
          _quotes[entry.key] = _merge(current, fields);
          any = true;
        }
      }
      _failure = invalid ? QuoteFailure.data : null;
      if (any) _updatedAt = _now();
    } catch (_) {
      if (!_disposed && epoch == _epoch) _failure = QuoteFailure.snapshot;
    } finally {
      _refreshing = false;
      _publish();
      if (_refreshAgain && !_disposed && _active) {
        _refreshAgain = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stop();
    await _output.close();
  }
}

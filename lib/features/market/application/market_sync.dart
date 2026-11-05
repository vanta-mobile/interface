import 'dart:async';

import 'package:decimal/decimal.dart';

import '../../../core/market_failure.dart';
import '../data/aster_service.dart';
import '../data/candle_history_repository.dart';
import '../domain/candle_series.dart';
import '../domain/market.dart';

class SyncOverview {
  const SyncOverview({
    required this.loaded,
    required this.total,
    required this.connected,
    required this.repairing,
    required this.failed,
  });
  final int loaded, total, repairing, failed;
  final bool connected;
}

/// Synchronizes one chart. Inactive charts retain candles without doing work.
class MarketSync {
  MarketSync(this.service, this.instrument, this.interval, {CandleHistoryRepository? history})
    : _history = history ?? CandleHistoryRepository(service),
      _ownsHistory = history == null,
      series = CandleSeries(SeriesKey(instrument.symbol, interval)),
      _ticker = instrument.ticker;
  final AsterService service;
  final AsterInstrument instrument;
  final String interval;
  final CandleSeries series;
  final CandleHistoryRepository _history;
  final bool _ownsHistory;
  Map<String, Object?> _ticker;
  final _updates = StreamController<Set<String>>.broadcast();
  StreamSubscription<Map<String, Object?>>? _subscription;
  Timer? _publish, _retry, _reconcile;
  Future<void>? _loading;
  final _older = <int, Candle>{};
  bool historyLoading = false, historyExhausted = false;
  String? historyFailure;
  String? failure;
  bool initialized = false, connected = false;
  bool _disposed = false, _active = false, _hadConnection = false;
  bool _needsRefresh = true, _again = false, _changed = false;
  int _generation = 0;
  Stream<Set<String>> get updates => _updates.stream;
  SyncOverview get overview => SyncOverview(
    loaded: initialized ? 1 : 0,
    total: 1,
    connected: connected,
    repairing: _loading == null ? 0 : 1,
    failed: failure == null ? 0 : 1,
  );

  void start() {
    if (_disposed || _active) return;
    _active = true;
    _hadConnection = false;
    _needsRefresh = true;
    // The current chart's REST request never waits for a WS handshake.
    _connect();
    retry();
    _reconcile = Timer.periodic(const Duration(seconds: 60), (_) {
      retry();
      unawaited(_refreshTicker());
    });
    _publish = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_changed) _notify();
    });
    _retry = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!connected || _needsRefresh || failure != null || series.missingRange != null) retry();
    });
  }

  void _connect() {
    final generation = ++_generation;
    _subscription = service.stream(['${instrument.symbol.toLowerCase()}@kline_$interval']).listen((
      event,
    ) {
      if (_active && generation == _generation) _onEvent(event);
    });
  }

  Future<void> reconnect() async {
    if (_disposed || !_active) return;
    connected = false;
    _needsRefresh = true;
    _notify();
    final generation = ++_generation;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (!_disposed && _active && generation == _generation) _connect();
  }

  Future<void> _refreshTicker() async {
    try {
      final tickers = await service.refreshTickers(symbol: instrument.symbol);
      if (_disposed || !_active) return;
      _ticker = tickers[instrument.symbol] ?? _ticker;
      _changed = true;
    } on Object {
      /* Keep the last public metadata; candle status remains independent. */
    }
  }

  void retry() {
    if (_disposed || !_active) return;
    if (_loading != null || historyLoading) {
      _again = true;
      return;
    }
    _loading = _load().whenComplete(() {
      _loading = null;
      _notify();
      final again = _again;
      _again = false;
      if (again && failure == null) retry();
    });
  }

  void _onEvent(Map<String, Object?> event) {
    if (_disposed) return;
    if (event['connected'] == true) {
      final reconnect = _hadConnection;
      _hadConnection = true;
      connected = true;
      if (reconnect) retry();
      _changed = true;
      return;
    }
    if (event['disconnected'] == true) {
      connected = false;
      _needsRefresh = true;
      _changed = true;
      return;
    }
    final raw = event['k'];
    if (event['e'] != 'kline' ||
        raw is! Map<String, dynamic> ||
        raw['i'] != interval ||
        raw['s'] != instrument.symbol) {
      return;
    }
    try {
      final candle = AsterService.liveCandle(event);
      if (series.mergeLive(series.key, candle)) {
        _changed = true;
        if (initialized && series.missingRange != null) retry();
      }
    } on MarketFailure catch (error) {
      failure = error.message;
      _needsRefresh = true;
      _changed = true;
    }
  }

  void _notify() {
    if (!_active || _disposed) return;
    _changed = false;
    _updates.add(Set.unmodifiable({instrument.symbol}));
  }

  Future<void> _load() async {
    bool shouldCancel() => _disposed || !_active;
    try {
      if (!initialized) {
        final revision = series.revision;
        final history = await _history.load(series.key, cancelled: shouldCancel);
        if (_disposed) return;
        if (history.isEmpty) throw const MarketFailure('Aster returned no historical candles');
        series.mergeHistory(series.key, history, requestRevision: revision);
        initialized = true;
        // No redundant boundary query after a complete initial snapshot.
        if (series.missingRange == null) {
          _needsRefresh = !_active;
          failure = null;
          return;
        }
        _notify();
      }
      if (shouldCancel()) return;
      final gap = series.missingRange;
      final latest = series.lastTime;
      if (latest != null) {
        var cursor = gap?.$1 ?? series.key.shift(latest, -2);
        final end = gap?.$2 ?? service.serverNow;
        while (cursor <= end) {
          final revision = series.revision;
          final pageLimit = candleCount(interval, cursor, end).clamp(1, 1000);
          final page = await _history.load(
            series.key,
            start: cursor,
            end: end,
            limit: pageLimit,
            cancelled: shouldCancel,
          );
          if (_disposed) return;
          if (page.isEmpty) break;
          series.mergeHistory(series.key, page, requestRevision: revision);
          final next = series.key.shift(page.last.time);
          if (next <= cursor) throw const MarketFailure('Historical pagination did not advance');
          cursor = next;
          if (shouldCancel()) return;
          _changed = true;
          if (page.length < pageLimit) break;
        }
      }
      if (shouldCancel()) return;
      if (series.missingRange != null) {
        failure = 'Candle gap: waiting for Aster history';
        _needsRefresh = true;
      } else {
        failure = null;
        _needsRefresh = false;
      }
    } on HistoryCancelled {
      // Obsolete queued requests must not consume network or weight budget.
    } on Object catch (error) {
      if (!_disposed) {
        _needsRefresh = true;
        failure = error is MarketFailure ? error.message : 'Aster connection unavailable';
      }
    }
  }

  Market? market(String symbol) {
    if (symbol != instrument.symbol || !initialized || series.candles.isEmpty) return null;
    final recent = series.candles;
    if (_older.isNotEmpty) {
      for (final candle in recent) {
        _older[candle.time] = candle;
      }
    }
    final candles = ({..._older, for (final candle in recent) candle.time: candle}).values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final close = candles.last.close;
    final open = AsterService.numeric(_ticker['openPrice']);
    return Market(
      symbol: symbol,
      interval: interval,
      price: Decimal.parse(close.toString()),
      change: (close - open) / open * 100,
      mark: AsterService.numeric(_ticker['markPrice'] ?? close),
      index: AsterService.numeric(_ticker['indexPrice'] ?? close),
      high: AsterService.numeric(_ticker['highPrice']),
      low: AsterService.numeric(_ticker['lowPrice']),
      volume: AsterService.numeric(_ticker['quoteVolume']),
      funding: AsterService.numeric(_ticker['lastFundingRate'] ?? 0) * 100,
      nextFunding: (_ticker['nextFundingTime'] as num? ?? 0).toInt(),
      candles: List.unmodifiable(candles),
      offline: !connected || _needsRefresh,
      failure: failure,
      historyLoading: historyLoading,
      historyExhausted: historyExhausted,
      historyFailure: historyFailure,
      precision: instrument.precision,
    );
  }

  /// Only invoked by an explicit browse action in the selected chart.
  Future<void> loadOlder() async {
    if (_disposed || !_active || !initialized || historyLoading || historyExhausted) return;
    final candles = market(instrument.symbol)!.candles;
    final end = candles.first.time - 1;
    historyLoading = true;
    historyFailure = null;
    _notify();
    try {
      await _loading;
      if (_disposed || !_active) return;
      final page = await _history.load(
        series.key,
        end: end,
        cancelled: () => _disposed || !_active,
      );
      if (_disposed) return;
      final earlier = page.where((c) => c.time <= end).toList();
      // Keep the old visible window as the live series advances/trims.
      for (final candle in [...candles, ...earlier]) {
        _older.putIfAbsent(candle.time, () => candle);
      }
      historyExhausted = earlier.isEmpty;
    } on HistoryCancelled {
      // A switch cancels queued work without exposing an error on another chart.
    } on Object catch (error) {
      if (!_disposed) {
        historyFailure = error is MarketFailure ? error.message : 'Aster connection unavailable';
      }
    } finally {
      historyLoading = false;
      _notify();
      if (_again && _active && !_disposed) {
        _again = false;
        retry();
      }
    }
  }

  Future<void> pause() async {
    _active = false;
    connected = false;
    _generation++;
    _needsRefresh = true;
    _again = false;
    _publish?.cancel();
    _retry?.cancel();
    _reconcile?.cancel();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    await pause();
    if (_ownsHistory) _history.dispose();
    await _updates.close();
  }
}

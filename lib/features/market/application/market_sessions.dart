import 'dart:async';

import '../data/aster_service.dart';
import '../data/candle_history_repository.dart';
import '../domain/candle_series.dart';
import 'market_sync.dart';

/// Creates caches only for charts the user opens. Only the visible chart syncs.
class MarketSessions {
  MarketSessions(this.service, this.instruments) : _history = CandleHistoryRepository(service);
  final AsterService service;
  final List<AsterInstrument> instruments;
  final CandleHistoryRepository _history;
  final _sessions = <SeriesKey, MarketSync>{};
  MarketSync? _active;
  bool _disposed = false;

  MarketSync select(String interval, String symbol) {
    if (_disposed) throw StateError('Market sessions disposed');
    if (!candleIntervals.contains(interval)) throw ArgumentError.value(interval, 'interval');
    final instrument = instruments.firstWhere((instrument) => instrument.symbol == symbol);
    final next = _sessions.putIfAbsent(
      SeriesKey(symbol, interval),
      () => MarketSync(service, instrument, interval, history: _history),
    );
    if (_active != next) unawaited(_active?.pause());
    _active = next;
    next.start();
    return next;
  }

  Future<void> dispose() async {
    _disposed = true;
    _history.dispose();
    await Future.wait(_sessions.values.map((session) => session.dispose()));
    _sessions.clear();
  }
}

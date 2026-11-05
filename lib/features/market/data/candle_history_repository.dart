import 'dart:async';

import '../domain/candle_series.dart';
import '../domain/market.dart';
import 'aster_service.dart';

class HistoryCancelled implements Exception {
  const HistoryCancelled();
}

/// Bounds outstanding history across rapid chart switches. Drops obsolete work
/// before it reaches the service; already-started responses stay in their cache.
class CandleHistoryRepository {
  CandleHistoryRepository(this.service);
  final AsterService service;
  final _queue = <_HistoryRequest>[];
  int _running = 0;
  bool _disposed = false;

  Future<List<Candle>> load(
    SeriesKey key, {
    int? start,
    int? end,
    int limit = 200,
    required bool Function() cancelled,
  }) {
    if (_disposed || cancelled()) return Future.error(const HistoryCancelled());
    final request = _HistoryRequest(
      cancelled,
      () => service.history(key.symbol, key.interval, start: start, end: end, limit: limit),
    );
    _queue.add(request);
    _pump();
    return request.result.future;
  }

  void _pump() {
    while (!_disposed && _running < 5 && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      if (request.cancelled()) {
        request.result.completeError(const HistoryCancelled());
        continue;
      }
      _running++;
      unawaited(_run(request));
    }
  }

  Future<void> _run(_HistoryRequest request) async {
    try {
      request.result.complete(await request.run());
    } on Object catch (error, stack) {
      request.result.completeError(error, stack);
    } finally {
      _running--;
      _pump();
    }
  }

  void dispose() {
    _disposed = true;
    for (final request in _queue) {
      request.result.completeError(const HistoryCancelled());
    }
    _queue.clear();
  }
}

class _HistoryRequest {
  _HistoryRequest(this.cancelled, this.run);
  final bool Function() cancelled;
  final Future<List<Candle>> Function() run;
  final result = Completer<List<Candle>>();
}

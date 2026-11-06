import '../../../core/network/request_scope.dart';

import 'dart:async';

import '../domain/mark_prices.dart';
import 'aster_service.dart';
import 'mark_price_mapper.dart';

/// Public marks for the requested positions, including delisted contracts.
/// No trading catalog, last-trade price, wallet or signing is involved.
class MarkPricesRepository {
  MarkPricesRepository(
    this.service,
    Set<String> symbols, {
    this._active = true,
    DateTime Function()? now,
  }) : symbols = Set.unmodifiable(symbols),
       _now = now ?? DateTime.now {
    _output = StreamController<MarkPrices>.broadcast(onListen: _start, onCancel: _stop);
  }
  final AsterService service;
  final Set<String> symbols;
  final DateTime Function() _now;
  late final StreamController<MarkPrices> _output;
  final _quotes = <String, MarkPriceQuote>{};
  final _symbolRevisions = <String, int>{};
  final _verified = <String>{}, _invalid = <String>{};
  StreamSubscription<Map<String, Object?>>? _subscription;
  Timer? _publishTimer, _freshnessTimer;
  bool _active, _disposed = false, _connected = false, _connecting = true;
  bool _hadConnection = false, _snapshotFailed = false;
  int _revision = 0;
  int? _loadingRevision;
  Stream<MarkPrices> get events => _output.stream;

  MarkPrices get state {
    final now = _now();
    return MarkPrices(
      quotes: _quotes,
      fresh: {
        for (final quote in _quotes.values)
          if (_active &&
              _connected &&
              _verified.contains(quote.symbol) &&
              !_invalid.contains(quote.symbol) &&
              now.difference(quote.receivedAt) >= Duration.zero &&
              now.difference(quote.receivedAt) < const Duration(seconds: 10) &&
              service.serverNow - quote.eventTime.millisecondsSinceEpoch >= -10000 &&
              service.serverNow - quote.eventTime.millisecondsSinceEpoch < 10000)
            quote.symbol,
      },
      invalid: _invalid,
      connection: !_active || (!_connected && !_connecting)
          ? MarkPriceConnection.offline
          : _connected
          ? MarkPriceConnection.online
          : MarkPriceConnection.connecting,
      snapshotFailed: _snapshotFailed,
    );
  }

  void _publish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!_disposed && _output.hasListener) _output.add(state);
  }

  void _start() {
    if (_disposed || !_active || _subscription != null || symbols.isEmpty) return;
    _connecting = true;
    _hadConnection = false;
    final revision = _revision;
    _subscriptionRevision = revision;
    _subscription = service
        .stream(['!markPrice@arr@1s'])
        .listen(
          (event) {
            if (!_disposed && _active && revision == _subscriptionRevision) _onEvent(event);
          },
          onError: (Object _) {
            if (!_disposed && _active && revision == _subscriptionRevision) _disconnect();
          },
          onDone: () {
            if (!_disposed && _active && revision == _subscriptionRevision) _disconnect();
          },
        );
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
    _publish();
    unawaited(_refresh());
  }

  int _subscriptionRevision = 0;

  void _disconnect() {
    _connected = _connecting = false;
    _verified.clear();
    _revision++;
    _publish();
  }

  void _onEvent(Map<String, Object?> event) {
    if (event['connected'] == true) {
      if (_connected) return;
      _connected = true;
      _connecting = false;
      if (_hadConnection) unawaited(_refresh());
      _hadConnection = true;
      _publish();
      return;
    }
    if (event['disconnected'] == true) {
      _disconnect();
      return;
    }
    if (!_connected || event['e'] != 'markPriceUpdate' || !symbols.contains(event['s'])) return;
    final symbol = event['s']! as String;
    _symbolRevisions.update(symbol, (n) => n + 1, ifAbsent: () => 1);
    try {
      final quote = mapMarkPrice(event, receivedAt: _now(), stream: true);
      if (!_acceptable(quote)) return;
      _quotes[symbol] = quote;
      _verified.add(symbol);
      _invalid.remove(symbol);
    } on FormatException {
      _invalid.add(symbol);
      _verified.remove(symbol);
    }
    _publishTimer ??= Timer(const Duration(milliseconds: 250), _publish);
  }

  bool _acceptable(MarkPriceQuote quote) {
    final serverAge = service.serverNow - quote.eventTime.millisecondsSinceEpoch;
    // Reject delayed replay and implausible future timestamps. The service
    // clock is calibrated by the existing public market initialization.
    if (serverAge < -10000 || serverAge >= 10000) return false;
    final previous = _quotes[quote.symbol];
    if (previous != null && !quote.eventTime.isAfter(previous.eventTime)) return false;
    return true;
  }

  Future<void> _refresh() async {
    final revision = _revision;
    if (_disposed || !_active || _loadingRevision == revision) return;
    _loadingRevision = revision;
    final baseline = Map.of(_symbolRevisions);
    try {
      final payload = await RequestScope.run(
        () => !_disposed && _active && revision == _revision,
        () => service.request('/fapi/v3/premiumIndex'),
      );
      if (_disposed || !_active || revision != _revision) return;
      if (payload is! List) throw const FormatException();
      final seen = <String>{};
      final parsed = <String, MarkPriceQuote>{};
      for (final row in payload) {
        if (row is! Map<String, dynamic> || !symbols.contains(row['symbol'])) continue;
        final quote = mapMarkPrice(row, receivedAt: _now());
        if (!seen.add(quote.symbol)) throw const FormatException();
        parsed[quote.symbol] = quote;
      }
      for (final quote in parsed.values) {
        // A late REST response cannot replace a mark received during its request.
        if (_symbolRevisions[quote.symbol] != baseline[quote.symbol] || !_acceptable(quote)) {
          continue;
        }
        _quotes[quote.symbol] = quote;
        _verified.add(quote.symbol);
        _invalid.remove(quote.symbol);
      }
      _snapshotFailed = symbols.any((s) => !parsed.containsKey(s));
    } catch (_) {
      if (!_disposed && revision == _revision) _snapshotFailed = true;
    } finally {
      if (_loadingRevision == revision) _loadingRevision = null;
      if (!_disposed && revision == _revision) _publish();
    }
  }

  Future<void> _stop() async {
    _revision++;
    _subscriptionRevision++;
    _freshnessTimer?.cancel();
    _publishTimer?.cancel();
    _publishTimer = null;
    _verified.clear();
    _connected = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> setActive(bool active) async {
    if (_disposed || active == _active) return;
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stop();
    await _output.close();
  }
}

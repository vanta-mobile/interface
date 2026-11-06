import '../../../core/network/request_scope.dart';

import 'dart:async';

import '../domain/order_reference_prices.dart';
import 'aster_service.dart';
import 'order_reference_price_mapper.dart';

/// Exact, public-only quotes for the active order symbol. Consumers still need
/// separately dated account/risk facts; these prices never authorize an order.
class OrderReferencePricesRepository {
  OrderReferencePricesRepository(
    this.service,
    this.symbol, {
    this._active = true,
    this.includeBook = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol)) {
      throw ArgumentError('Invalid order symbol');
    }
    _output = StreamController<OrderReferencePrices>.broadcast(onListen: _start, onCancel: _stop);
  }
  final AsterService service;
  final String symbol;
  final bool includeBook;
  final DateTime Function() _now;
  late final StreamController<OrderReferencePrices> _output;
  StreamSubscription<Map<String, Object?>>? _subscription;
  Timer? _publishTimer, _freshnessTimer;
  OrderBookQuote? _book;
  OrderTradeQuote? _trade;
  int? _bookId, _serverTime;
  int _clockLatency = 0;
  DateTime? _clockAt;
  int _revision = 0, _streamRevision = 0;
  int _bookRevision = 0, _tradeRevision = 0;
  bool _active, _disposed = false, _connected = false, _connecting = true;
  bool _bookVerified = false, _tradeVerified = false;
  bool _bookFailed = false, _tradeFailed = false;
  Stream<OrderReferencePrices> get events => _output.stream;

  bool _fresh(DateTime event, DateTime received) {
    final now = _now(), calibration = _clockAt;
    if (!_active || !_connected || calibration == null || _serverTime == null) return false;
    final elapsed = now.difference(calibration), age = now.difference(received);
    final serverAge = _serverTime! + elapsed.inMilliseconds - event.millisecondsSinceEpoch;
    return !elapsed.isNegative &&
        !age.isNegative &&
        age < const Duration(seconds: 10) &&
        serverAge >= -10000 &&
        // The server stamped its response between request start and receipt.
        // Use the upper bound of that interval for expiry, so network latency
        // cannot make an already old transaction look newer than ten seconds.
        serverAge + _clockLatency < 10000;
  }

  OrderReferencePrices get state => OrderReferencePrices(
    symbol: symbol,
    checkedAt: _now(),
    book: _book,
    trade: _trade,
    connection: !_active || !_connected && !_connecting
        ? OrderPriceConnection.offline
        : _connected
        ? OrderPriceConnection.online
        : OrderPriceConnection.connecting,
    bookFresh: _bookVerified && _book != null && _fresh(_book!.eventTime, _book!.receivedAt),
    tradeFresh: _tradeVerified && _trade != null && _fresh(_trade!.eventTime, _trade!.receivedAt),
    bookFailed: _bookFailed,
    tradeFailed: _tradeFailed,
  );

  void _publish() {
    _publishTimer?.cancel();
    _publishTimer = null;
    if (!_disposed && _output.hasListener) _output.add(state);
  }

  void _start() {
    if (_disposed || !_active || !_output.hasListener || _subscription != null) return;
    _connecting = true;
    final token = ++_streamRevision;
    bool current() => !_disposed && _active && token == _streamRevision;
    try {
      _subscription = service
          .stream([
            if (includeBook) '${symbol.toLowerCase()}@bookTicker',
            '${symbol.toLowerCase()}@aggTrade',
          ])
          .listen(
            (event) {
              if (current()) _onEvent(event);
            },
            onError: (Object _) {
              if (current()) _disconnect();
            },
            onDone: () {
              if (current()) _disconnect();
            },
          );
      _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
    } catch (_) {
      _connected = _connecting = false;
    }
    _publish();
  }

  void _disconnect() {
    _revision++;
    _connected = _connecting = false;
    _bookVerified = _tradeVerified = false;
    _clockAt = null;
    _publish();
  }

  void _onEvent(Map<String, Object?> event) {
    if (event['connected'] == true) {
      if (_connected) return;
      _connected = true;
      _connecting = false;
      _bookVerified = _tradeVerified = false;
      _clockAt = null;
      final revision = ++_revision;
      _publish();
      unawaited(_refresh(revision));
      return;
    }
    if (event['disconnected'] == true) {
      _disconnect();
      return;
    }
    // A calibrated public clock and a connected transport are required before
    // accepting events. The REST bootstrap fills the initial pre-clock gap.
    if (!_connected || _clockAt == null || event['s'] != symbol) return;
    if (includeBook && event['e'] == 'bookTicker') {
      _bookRevision++;
      try {
        final quote = mapOrderBookQuote(event, symbol: symbol, receivedAt: _now(), stream: true);
        if (_acceptBook(quote)) {
          _book = quote;
          _bookId = quote.updateId;
          _bookVerified = true;
          _bookFailed = false;
        }
      } on FormatException {
        _bookVerified = false;
        _bookFailed = true;
      }
    } else if (event['e'] == 'aggTrade') {
      _tradeRevision++;
      try {
        final quote = mapOrderTradeQuote(event, symbol: symbol, receivedAt: _now(), stream: true);
        if (_acceptTrade(quote)) {
          _trade = quote;
          _tradeVerified = true;
          _tradeFailed = false;
        }
      } on FormatException {
        _tradeVerified = false;
        _tradeFailed = true;
      }
    } else {
      return;
    }
    _publishTimer ??= Timer(const Duration(milliseconds: 250), _publish);
  }

  bool _acceptBook(OrderBookQuote quote, {bool rest = false}) {
    if (!_fresh(quote.eventTime, quote.receivedAt)) return false;
    final previous = _book;
    if (previous == null) return true;
    if (quote.eventTime.isBefore(previous.eventTime)) return false;
    if (rest) return true; // Caller also verifies no stream update during REST.
    return (_bookId == null || quote.updateId! > _bookId!) &&
        (quote.eventTime.isAfter(previous.eventTime) ||
            quote.eventTime == previous.eventTime && quote.updateId != null);
  }

  bool _acceptTrade(OrderTradeQuote quote, {bool rest = false}) {
    if (!_fresh(quote.eventTime, quote.receivedAt)) return false;
    final previous = _trade;
    if (previous == null) return true;
    if (quote.eventTime.isBefore(previous.eventTime)) return false;
    if (quote.tradeId > previous.tradeId) return true;
    return rest &&
        quote.tradeId == previous.tradeId &&
        quote.eventTime == previous.eventTime &&
        quote.price == previous.price;
  }

  Future<void> _refresh(int revision) async {
    bool current() => !_disposed && _active && _connected && revision == _revision;
    final baselineBook = _book, baselineTrade = _trade;
    try {
      final startedAt = _now();
      final clock = await RequestScope.run(current, () => service.request('/fapi/v3/time'));
      if (!current()) return;
      final elapsed = _now().difference(startedAt);
      if (clock is! Map<String, dynamic> ||
          clock['serverTime'] is! int ||
          (clock['serverTime'] as int) <= 0 ||
          (clock['serverTime'] as int) > 253402300799999 ||
          elapsed.isNegative ||
          elapsed >= const Duration(seconds: 10)) {
        throw const FormatException();
      }
      _serverTime = clock['serverTime'] as int;
      _clockAt = _now();
      _clockLatency = elapsed.inMilliseconds;
      // Keep the two public snapshots independent: one failed channel does not
      // erase a successful or subsequently recovered channel.
      await Future.wait([
        if (includeBook) _readBook(current, baselineBook, _bookRevision),
        _readTrade(current, baselineTrade, _tradeRevision),
      ]);
    } catch (_) {
      if (current()) _bookFailed = _tradeFailed = true;
    } finally {
      if (current()) _publish();
    }
  }

  Future<void> _readBook(bool Function() current, OrderBookQuote? baseline, int revision) async {
    try {
      final raw = await RequestScope.run(
        current,
        () => service.request('/fapi/v3/ticker/bookTicker', {'symbol': symbol}),
      );
      if (!current()) return;
      final quote = mapOrderBookQuote(raw, symbol: symbol, receivedAt: _now());
      if (!identical(_book, baseline) || revision != _bookRevision) return;
      if (!_acceptBook(quote, rest: true)) throw const FormatException();
      _book = quote;
      _bookVerified = true;
      _bookFailed = false;
    } catch (_) {
      if (current() && identical(_book, baseline) && revision == _bookRevision) {
        _bookVerified = false;
        _bookFailed = true;
      }
    }
  }

  Future<void> _readTrade(bool Function() current, OrderTradeQuote? baseline, int revision) async {
    try {
      final raw = await RequestScope.run(
        current,
        () => service.request('/fapi/v3/trades', {'symbol': symbol, 'limit': '1'}),
      );
      if (!current()) return;
      final quote = mapOrderTradeQuote(raw, symbol: symbol, receivedAt: _now());
      if (!identical(_trade, baseline) || revision != _tradeRevision) return;
      if (!_acceptTrade(quote, rest: true)) throw const FormatException();
      _trade = quote;
      _tradeVerified = true;
      _tradeFailed = false;
    } catch (_) {
      if (current() && identical(_trade, baseline) && revision == _tradeRevision) {
        _tradeVerified = false;
        _tradeFailed = true;
      }
    }
  }

  Future<void> _stop() async {
    _revision++;
    _streamRevision++;
    _publishTimer?.cancel();
    _publishTimer = null;
    _freshnessTimer?.cancel();
    _bookVerified = _tradeVerified = false;
    _connected = false;
    _clockAt = null;
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

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Container-owned sockets and host budgets. Leases never own the pool.
class BackendHttpPool {
  BackendHttpPool({http.Client Function()? createClient})
    : _createClient =
          createClient ?? (() => IOClient(HttpClient()..idleTimeout = const Duration(minutes: 2)));
  final http.Client Function() _createClient;
  final _clients = <String, http.Client>{};
  final _budgets = <String, _HostBudget>{};
  final _closedSignal = Completer<void>();
  bool _closed = false;
  http.Client lease() => _PoolLease(this);

  Future<http.StreamedResponse> _send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('HTTP pool closed');
    final origin = request.url.origin;
    final budget = _budgets.putIfAbsent(origin, _HostBudget.new);
    final abort = request is http.Abortable ? request.abortTrigger : null;
    await budget.reserve(request, abort, _closedSignal.future);
    if (_closed) throw http.ClientException('HTTP pool closed');
    final response = await _clients.putIfAbsent(origin, _createClient).send(request);
    if (response.statusCode == 429 || response.statusCode == 418) {
      budget.cooldown(response.headers['retry-after']);
    }
    return response;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _closedSignal.complete();
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}

class _PoolLease extends http.BaseClient {
  _PoolLease(this.pool);
  final BackendHttpPool pool;
  bool _closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) throw http.ClientException('HTTP lease closed');
    return pool._send(request);
  }

  @override
  void close() => _closed = true;
}

class _HostBudget {
  final _weights = <(int, int)>[];
  int _blockedUntil = 0;
  Future<void> reserve(http.BaseRequest request, Future<void>? abort, Future<void> closed) async {
    final weighted = const {'fapi.asterdex.com', 'sapi.asterdex.com'}.contains(request.url.host);
    final weight = _weight(request.url);
    while (true) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _weights.removeWhere((entry) => entry.$1 <= now - 60000);
      final used = _weights.fold(0, (sum, entry) => sum + entry.$2);
      final budgetWait = weighted && used + weight > 1000 ? _weights.first.$1 + 60001 - now : 0;
      final wait = [budgetWait, _blockedUntil - now].reduce((a, b) => a > b ? a : b);
      if (wait <= 0) {
        if (weighted) _weights.add((now, weight));
        return;
      }
      final ready = Completer<void>();
      final timer = Timer(Duration(milliseconds: wait), ready.complete);
      try {
        await Future.any([
          ready.future,
          if (abort != null) abort.then((_) => throw http.RequestAbortedException(request.url)),
          closed.then((_) => throw http.ClientException('HTTP pool closed')),
        ]);
      } finally {
        timer.cancel();
      }
    }
  }

  void cooldown(String? retryAfter) {
    final now = DateTime.now();
    var delay = const Duration(seconds: 5);
    final seconds = int.tryParse(retryAfter ?? '');
    if (seconds != null) {
      delay = Duration(seconds: seconds.clamp(1, 86400));
    } else if (retryAfter != null) {
      try {
        delay = HttpDate.parse(retryAfter).difference(now);
      } on FormatException {
        // Keep the conservative fallback for an invalid server header.
      }
    }
    final until = now.add(delay).millisecondsSinceEpoch;
    if (until > _blockedUntil) _blockedUntil = until;
  }

  int _weight(Uri uri) {
    if (uri.path.endsWith('/klines')) {
      final limit = int.tryParse(uri.queryParameters['limit'] ?? '') ?? 0;
      return limit < 100
          ? 1
          : limit < 500
          ? 2
          : limit <= 1000
          ? 5
          : 10;
    }
    if (uri.path.endsWith('/ticker/24hr') && uri.queryParameters['symbol'] == null) {
      return 40;
    }
    if (uri.host == 'sapi.asterdex.com' &&
        uri.path.endsWith('/openOrders') &&
        uri.queryParameters['symbol'] == null) {
      return 40;
    }
    return 1;
  }
}
